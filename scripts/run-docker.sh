#!/bin/bash

SRC_DIR="$(pwd)"
OUT_DIR="${SRC_DIR}/pkgs"
HOME_DIR="${SRC_DIR}/home"
BUILD_DIR="${SRC_DIR}/build"
DOCKER_IMAGE="ghcr.io/built-aur/packages:latest"

mkdir -p \
  "${OUT_DIR}" \
  "${HOME_DIR}" \
  "${BUILD_DIR}"

echo "::group::[i] Pulling Docker Container..."
sudo docker pull "${DOCKER_IMAGE}"
echo "::endgroup::"

sudo docker run \
  --env BUILD_ARCH="${BUILD_ARCH}" \
  --mount type=bind,source="${SRC_DIR}",target=/mnt/src \
  --mount type=bind,source="${OUT_DIR}",target=/mnt/out \
  --mount type=bind,source="${HOME_DIR}",target=/mnt/home \
  --mount type=bind,source="${BUILD_DIR}",target=/mnt/build \
  "${DOCKER_IMAGE}" \
  su -c "/mnt/src/build-package.sh" build
