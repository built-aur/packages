#!/bin/bash

set -o errexit -o pipefail -o nounset

# Commit changes to Git.
: "${GIT_COMMIT_PACKAGES:=false}"
# Push changes to remote.
: "${GIT_PUSH_PACKAGES:=false}"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
SRC_DIR="$(realpath "$(dirname "${SCRIPT_DIR}")")"
TMP_DIR="$(mktemp -d -t medzik-aur-XXXX)"

mkdir "${TMP_DIR}/aur"

source "${SCRIPT_DIR}/lib/parse-conf.sh"

echo '::group::Adding aur.archlinux.org to known hosts'
ssh-keyscan -v -t "rsa,dsa,ecdsa,ed25519" aur.archlinux.org >>~/.ssh/known_hosts
echo '::endgroup::'

echo '::group::Importing private key'
echo "${SSH_PRIVATE_KEY}" >~/.ssh/aur
chmod -vR 600 ~/.ssh/aur*
ssh-keygen -vy -f ~/.ssh/aur >~/.ssh/aur.pub
echo '::endgroup::'

echo '::group::Checksums of SSH keys'
sha512sum ~/.ssh/aur ~/.ssh/aur.pub
echo '::endgroup::'

echo '::group::Configuring Git'
git config --global user.name "${COMMIT_USER}"
git config --global user.email "${COMMIT_EMAIL}"
echo '::endgroup::'

push() {
  local pkgdir="${1}"
  local pkgname="$(basename ${pkgdir})"

  if [ ! -f "${pkgdir}/built.conf" ]
  then
    return 0
  fi

  if [ ! -f "${pkgdir}/PKGBUILD" ]
  then
    return 0
  fi

  if [ -f "${pkgdir}/built.conf" ]
  then
    eval "$(parse-conf ${pkgdir})"

    cd "${SRC_DIR}"

    if [ -n "${AUR_PUSH}" ]
    then
      echo '::group::Cloning AUR package into /tmp/local-repo'
      git clone -v "https://aur.archlinux.org/${pkgname}.git" /tmp/local-repo
      echo '::endgroup::'

      echo '::group::Copying files into /tmp/local-repo'
      cp -r "${pkgdir}"/* /tmp/local-repo/
      rm -rf /tmp/local-repo//build.yml
      echo '::endgroup::'

      echo '::group::Generating .SRCINFO'
      cd /tmp/local-repo
      makepkg --printsrcinfo >.SRCINFO
      echo '::endgroup::'

      echo '::group::Committing files to the repository'
      git add /tmp/local-repo
      git commit -m "sync with built-aur"
      echo '::endgroup::'

      echo '::group::Push package to AUR'
      git push -v origin master
      echo '::endgroup::'
      return 0
    fi
  fi
}

if [ -n "${1}" ]
then
  update-package "./packages/${1}"
  update-package "./long-built/${1}"
  exit 0
fi

for pkgdir in ./packages/* ./long-built/*
do
  push "${pkgdir}"

  EXIT_CODE="${?}"

  if ! (( ${EXIT_CODE} ))
  then
    if [ "${GIT_PUSH_PACKAGES}" = "true" ]
    then
      git pull --rebase &> /dev/null
      git push &> /dev/null
    fi
  else
    echo "[!] Failed to update package '$(basename ${pkgdir})'"
  fi
done
