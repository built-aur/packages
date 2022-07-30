#!/bin/bash

# Enable commit changes to git
: "${GIT_COMMIT_PACKAGES:=false}"
# Enable push changes to git
: "${GIT_PUSH_PACKAGES:=false}"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
SRC_DIR="$(realpath "$(dirname "${SCRIPT_DIR}")")"
TMP_DIR="$(mktemp -d -t medzik-aur-XXXX)"

mkdir "${TMP_DIR}/aur"

source "${SCRIPT_DIR}/lib/parse-conf.sh"

compare_version() {
  if $(${SCRIPT_DIR}/compare-versions.py "${1}" "${2}")
  then
    return 0 # true - update needed
  else
    return 1 # false - update not needed
  fi
}

update-package() {
  local pkgdir="${1}"
  local pkgname="$(basename ${pkgdir})"

  trap 'echo "Error code $? occurred in package ${pkgname} on line ${LINENO}" 1>&2 ; return 1' ERR

  if [ ! -f "${pkgdir}/built.conf" ]
  then
    return 0
  fi

  eval "$(parse-conf ${pkgdir})"

  cd "${SRC_DIR}"

  # check the package updates from AUR
  if [ ! -f "${pkgdir}/PKGBUILD" ]
  then
    if [ -n "${AUR_NAME}" ]
    then
      if [ -n "${AUR_PKGBASE}" ]
      then
        local latest_version="latest"
        local last_updated="$(git ls-remote --quiet https://aur.archlinux.org/${AUR_NAME}.git refs/heads/master | awk '{print $1}')"
      else
        local latest_version="$(curl --location --silent "https://aur.archlinux.org/rpc/?v=5&type=info&arg=${AUR_NAME}" | jq -r '.results[0].Version')"
        local last_updated="$(curl --location --silent "https://aur.archlinux.org/rpc/?v=5&type=info&arg=${AUR_NAME}" | jq -r '.results[0].LastModified')"
      fi

      local version="${AUR_UPDATED}"

      if [[ -z "${last_updated}" || "${last_updated}" = "null" ]]
      then
        echo "[!] Failed to get latest version of ${pkgname}"
        return 1
      fi

      if [ "${version}" = "${last_updated}" ]
      then
        return 0
      fi

      sed -i "s|^\(AUR_UPDATED=\)\(.*\)\$|\1\"${last_updated}\"|g" "${pkgdir}/built.conf"

      if [ "${GIT_COMMIT_PACKAGES}" = "true" ]
      then
        git add "${pkgdir}/built.conf"
        git commit -m "upgpkg(${pkgname}): ${latest_version}"
      fi

      echo "[i] Updated '${pkgname}' to '${latest_version}'"

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
        local latest_version="$(curl --location --silent -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/repos/${GITHUB_REPO}/tags" | jq -r '.[0].name')"
      else
        local latest_version="$(curl --silent --location -H "Authorization: token ${GITHUB_API_TOKEN}" "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r ".tag_name")"
      fi

      if [[ -z "${latest_version}" || "${latest_version}" = "null" ]]
      then
        echo "[!] Failed to get latest version of ${pkgname}"
        return 1
      fi

      custom_vars=$(
        . "${pkgdir}/PKGBUILD"
        echo "local version=${pkgver}"
      )

      eval "${custom_vars}"

      # Translate "_" into ".": some packages use underscores to seperate
      # version numbers, but we require them to be separated by dots.
      latest_version=${latest_version//_/.}

      # Remove leading 'v' or 'r'
      latest_version=${latest_version#[v,r]}

      # Translate "-" into ".": pacman does not support - in pkgver
      latest_version=${latest_version//-/.}

      if ! $(compare_version "${version}" "${latest_version}")
      then
        return 0
      fi

      sed -i "s|^\(pkgver=\)\(.*\)\$|\1\"${latest_version}\"|g" "${pkgdir}/PKGBUILD"
      sed -i "s|^\(pkgrel=\)\(.*\)\$|\11|g" "${pkgdir}/PKGBUILD"

      # Update package checksums
      cd "${pkgdir}"
      chown -R build .
      su -c 'updpkgsums' build
      cd "${SRC_DIR}"

      if [ "${GIT_COMMIT_PACKAGES}" = "true" ]
      then
        git add "${pkgdir}/PKGBUILD"
        git commit -m "upgpkg(${pkgname}): ${latest_version}"
      fi

      echo "[i] Updated '${pkgname}' to '${latest_version}'"

      return 0
    fi

    if [ -n "${NPM}" ]
    then
      local latest_version="$(curl --location --silent "https://unpkg.com/${NPM}/package.json" | jq -r ".version")"

      if [[ -z "${latest_version}" || "${latest_version}" = "null" ]]
      then
        echo "[!] Failed to get latest version of ${pkgname}"
        return 1
      fi

      custom_vars=$(
        . "${pkgdir}/PKGBUILD"
        echo "local version=${pkgver}"
      )

      eval "${custom_vars}"

      if ! $(compare_version "${version}" "${latest_version}")
      then
        return 0
      fi

      sed -i "s|^\(pkgver=\)\(.*\)\$|\1\"${latest_version}\"|g" "${pkgdir}/PKGBUILD"
      sed -i "s|^\(pkgrel=\)\(.*\)\$|\11|g" "${pkgdir}/PKGBUILD"

      # Update package checksums
      cd "${pkgdir}"
      chown -R build .
      su -c 'updpkgsums' build
      cd "${SRC_DIR}"

      if [ "${GIT_COMMIT_PACKAGES}" = "true" ]
      then
        git add "${pkgdir}/PKGBUILD"
        git commit -m "upgpkg(${pkgname}): ${latest_version}"
      fi

      echo "[i] Updated '${pkgname}' to '${latest_version}'"

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
