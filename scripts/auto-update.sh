#!/bin/bash

# Commit changes to Git.
: "${GIT_COMMIT_PACKAGES:=false}"
# Push changes to remote.
: "${GIT_PUSH_PACKAGES:=false}"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

source "${SCRIPT_DIR}/lib/parse-conf.sh"

aur-version() {
  curl --location --silent "https://aur.archlinux.org/rpc/?v=5&type=info&arg=${1}" | jq -r '.results[0].Version'
}

gh-tag-version() {
  curl --location --silent -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/repos/${1}/tags" | jq -r '.[0].name'
}

gh-version() {
  curl --silent --location -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/repos/${1}/releases/latest" | jq -r ".tag_name"
}

update-package() {
  local pkgdir="${1}"
  local pkgname="$(basename ${pkgdir})"

  if [ ! -f "${pkgdir}/built.conf" ]
  then
    return 0
  fi

  eval "$(parse-conf ${pkgdir})"

  # check the package updates from AUR
  if [ ! -f "${pkgdir}/PKGBUILD" ]
  then
    if [ -n "${AUR_NAME}" ]
    then
      local version="${AUR_VERSION}"
      local latest_version="$(aur-version ${AUR_NAME})"

      if [ "${version}" = "${latest_version}" ]
      then
        return 0
      fi

      sed -i "s|^\(AUR_VERSION=\)\(.*\)\$|\1\"${latest_version}\"|g" "${pkgdir}/built.conf"

      if [ "${GIT_COMMIT_PACKAGES}" = "true" ]
      then
        git commit -m "upgpkg: '${pkgname}' to '${latest_version}'"
      fi

      return 0
    fi
  fi

  if [ -f "${pkgdir}/built.conf" ]
  then
    # check the package updates from github
    if [ -n "${GITHUB_REPO}" ]
    then
      # check latest version
      if [ "${GITHUB_TAG}" = "true" ]
      then
        local latest_version="$(gh-tag-version ${GITHUB_REPO})"
      else
        local latest_version="$(gh-version ${GITHUB_REPO})"
      fi

      custom_vars=$(
        . "${pkgdir}/PKGBUILD"
        echo "local version=${pkgver}"
      )

      eval "${custom_vars}"

      # Translate "_" into ".": some packages use underscores to seperate
      # version numbers, but we require them to be separated by dots.
      version=${latest_tag//_/.}

      # Remove leading 'v' or 'r'
      version=${version#[v,r]}

      # Translate "-" into ".": pacman does not support - in pkgver
      version=${version//-/.}

      if [ "${version}" = "${latest_version}" ]
      then
        return 0
      fi

      sed -i "s|^\(pkgver=\)\(.*\)\$|\1\"${latest_version}\"|g" "${pkgdir}/PKGBUILD"

      # Update package checksums
      updpkgsums

      if [ "${GIT_COMMIT_PACKAGES}" = "true" ]
      then
        git commit -m "upgpkg: '${pkgname}' to '${latest_version}'"
      fi

      return 0
    fi
  fi
}

for pkgdir in ./packages/*
do
  update-package "${pkgdir}"

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
