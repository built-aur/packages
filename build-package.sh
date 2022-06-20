#!/bin/bash

# dirs
BUILD_DIR="/mnt/build"
SRC_DIR="/mnt/src"
OUT_DIR="/mnt/out"
TMP_DIR="$(mktemp -d -t medzik-aur-XXXX)"
SCRIPT_DIR="$(realpath "$(dirname "$0")"/scripts)"

# load lib
source "${SCRIPT_DIR}/lib/parse-conf.sh"
source "${SCRIPT_DIR}/lib/build/patches.sh"

# change owner of the directories in /mnt to the current user
sudo chown -R $(id -u) /mnt/*

# makepkg flags
MAKEPKG_SYNCDEPS_FLAGS="--syncdeps --noconfirm --nobuild --noextract"
MAKEPKG_BUILD_FLAGS="--rmdeps --clean --skippgpcheck --nocheck --config /etc/makepkg.${BUILD_ARCH}.conf"

MAKEFLAGS="-j$(nproc)"

echo "[i] Creating /etc/buildtime..."
echo $(date +"%s") | sudo tee /etc/buildtime

cd "${SRC_DIR}"

# directory where temporary files with package names for the build will be created
PACKAGES_TO_BUILD_DIR="${TMP_DIR}/tobuilt"
mkdir -p "${PACKAGES_TO_BUILD_DIR}"

# check which packages to build
while IFS= read -r pkg
do
  built "${pkg}"
done < "${SRC_DIR}/built_packages.txt"

built() {
  pkgname="${1}"
  pkgdir="${SRC_DIR}/packages/${pkgname}"

  echo "::group::[i] Building '${pkgname}'"

  if [ ! -f "${pkgdir}/PKGBUILD" ]
  then
    eval "$(parse-conf ${pkgdir})"

    aur_name="${AUR_NAME}"

    git clone "https://aur.archlinux.org/${aur_name}.git" "${BUILD_DIR}/${pkgname}"

    EXIT_CODE="${?}"

    if (( ${EXIT_CODE} ))
    then
      echo "${pkgname} | exit code: ${EXIT_CODE}"
      echo "${pkgname} | exit code: ${EXIT_CODE}" >> "${SRC_DIR}/fail_built.txt"
      return ${EXIT_CODE}
    fi
  else
    mkdir "${BUILD_DIR}/${pkgname}"
    cp -r "${pkgdir}"/* "${BUILD_DIR}/${pkgname}/"
  fi

  cd "${BUILD_DIR}/${pkgname}"

  # run custom patches
  echo "[i] Running custom patches..."
  patches

  echo "[i] Installing dependencies..."
  for (( i=0; i<15; i++ ))
  do
    sudo pacman -Sy
    makepkg ${MAKEPKG_SYNCDEPS_FLAGS}

    EXIT_CODE="${?}"

    if ! (( ${EXIT_CODE} ))
    then
      break
    else
      sleep 2
      echo "==> Sychronizing dependencies... (attempt $i)"
    fi
  done

  SOURCE_DATE_EPOCH=$(cat /etc/buildtime) BUILDDIR="${BUILD_DIR}/makepkg" PKGDEST="${OUT_DIR}" makepkg ${MAKEPKG_BUILD_FLAGS}

  EXIT_CODE="${?}"

  if (( ${EXIT_CODE} ))
  then
    echo "${pkgname} | exit code: ${EXIT_CODE}"
    echo "${pkgname} | exit code: ${EXIT_CODE}" >> "${SRC_DIR}/fail_built.txt"
    return ${EXIT_CODE}
  fi

  echo "::endgroup::"
}

if [ -f "${SRC_DIR}/fail_built.txt" ]
then
  printf "\n\nFailed to build:\n"

  cat --number "${SRC_DIR}/fail_built.txt"

  exit 1
fi
