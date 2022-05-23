#!/bin/bash

# Env
# DOCKER_IMAGE_TAG - Docker image tag
#
# SFTP_HOST - sftp server host
# SFTP_USER - sftp username
# SFTP_PASSWORD - sftp password
# SFTP_CWD - sftp home directory
#
# PROGRESS_NAME - progress archive name, empty in not exists

# Outputs
# finished - build ended?

free_space() {
  echo "::group::Stage: Free space on GitHub Runner..."
  sudo rm -rf /usr/share/dotnet
  sudo rm -rf /usr/local/lib/android
  sudo rm -rf /opt/ghc
  echo "::endgroup::"
}

pull_image() {
  echo "::group::Stage: Pulling image from registry..."
  docker pull "${DOCKER_IMAGE_TAG}"
  echo "::endgroup::"
}

download_progress() {
  echo "::group::Stage: Downloading progress artifact..."
  SSHPASS="${SFTP_PASSWORD}" sshpass -e rsync -e ssh -avL "${SFTP_USER}@${SFTP_HOST}:${SFTP_CWD}/stage/${PROGRESS_NAME}" progress.tar.zst
  echo "::endgroup::"

  echo "::group::Stage: Moving progress archive into input directory..."
  mv progress.tar.zst input
  echo "::endgroup::"
}

upload_progress() {
  echo "::group::Stage: Downloading progress artifact..."
  SSHPASS="${SFTP_PASSWORD}" sshpass -e rsync -e ssh -avL "${SFTP_USER}@${SFTP_HOST}:${SFTP_CWD}/stage/" progress.tar.zst
  echo "::endgroup::"

  echo "::group::Stage: Moving progress archive into input directory..."
  mv progress.tar.zst input
  echo "::endgroup::"
}

run_docker() {
  echo "::group::Stage: Running docker container..."

  docker run \
    -e TIMEOUT=330 \
    --mount type=bind,source="input",target="/mnt/input" \
    --mount type=bind,source="output",target="/mnt/output" \
    --mount type=bind,source="progress",target="/mnt/progress" \
    "${DOCKER_IMAGE}"

  echo "::endgroup::"
}

free_space

pull_image

# create input, output and progress directory
mkdir input output progress

# Download progress artifact
if [ -z "${PROGRESS_NAME}" ]
then
  download_progress
fi

# Run stage build
run_docker

if [ -z "$(ls -A output)" ]
then
  # Directory is empty
  echo "::set-output name=finished::false"
else
  echo "Successfully built package"

  echo "::set-output name=finished::true"
fi

# echo "::set-output name=pnpm_cache_dir::$(pnpm store path)"
