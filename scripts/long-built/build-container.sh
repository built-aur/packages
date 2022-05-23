#!/bin/bash
set -e

echo "::group::Generating source archive..."

ROOT_DIR=$(pwd)
SCRIPT_DIR="$(realpath "$(dirname "$0")"/..)"

source "${SCRIPT_DIR}/lib/parse-conf.sh"

sudo chown build -R .

PACKAGE="$(cat ${ROOT_DIR}/built_packages.txt)"

pkgdir="${ROOT_DIR}/long-built/$PACKAGE"

clone_aur() {
  eval "$(parse-conf ${pkgdir})"

  rm -rf "${pkgdir}"

  git clone "https://aur.archlinux.org/${AUR_NAME}.git" "${pkgdir}"

  EXIT_CODE="${?}"

  if (( ${EXIT_CODE} ))
  then
    echo "exit code: ${code}"
    exit ${code}
  fi
}

if [ ! -f "${pkgdir}/PKGBUILD" ]
then
  clone_aur
fi

cd "${pkgdir}"

sudo chown build -R .

# Generate archive with all required sources for the build
# This either includes local or downloads files using an url
su -c "makepkg --allsource --skippgpcheck" build
mv ./*.src.tar.gz "${ROOT_DIR}"

cd "${ROOT_DIR}"

echo "::endgroup::"

VERSION="$(compgen -G "*.src.tar.gz" | grep -Po '([\d\.]+-\d*)')"
NAME="packages"
ID="$(echo "$REGISTRY"/$NAME | tr '[A-Z]' '[a-z]')"
REF="$(echo "$GH_REF" | sed -e 's,.*/\(.*\),\1,')"
[[ "${GH_REF}" == "refs/tags/"* ]] && REF=$(echo ${REF} | sed -e 's/^v//')
[ "${REF}" == "master" ] && REF=latest
VERSION_TAG="${ID}:${PACKAGE}-${VERSION}-$(date +%s)"

echo "VERSION=${VERSION}"
echo "REGISTRY=${REGISTRY}"
echo "NAME=${NAME}"
echo "ID=${ID}"
echo "REF=${REF}"
echo "VERSION_TAG=${VERSION_TAG}"

echo "::group::Building container image..."

# Build container from source files
docker build . \
  --file scripts/long-built/Dockerfile \
  --build-arg PACKAGE="${PACKAGE}" \
  --tag "${VERSION_TAG}" \

# Reduce worker space used
rm -rf ./*

echo "::endgroup::"

echo "::set-output name=version-tag::${VERSION_TAG}"
