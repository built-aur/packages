#!/bin/bash

cd /home/build

# variables
ROOT_DIR=$(pwd)
export HOME="/home/build"

# makepkg arguments
BUILD_ARGUMENTS="--skippgpcheck --config /etc/makepkg.${BUILD_ARCH}.conf"

# librewolf
sed -i 's|# mk_add_options MOZ_MAKE_FLAGS="-j4"|mk_add_options MOZ_MAKE_FLAGS="-j1"|g' PKGBUILD

# unpack compilation files from previous stage
unpack_stage() {
  echo "==> Extracting source archive..."
  sudo tar -xf /mnt/input/progress.tar.zst -C "$ROOT_DIR"

  echo "==> Deleting source archive..."
  sudo rm /mnt/input/*

  echo "==> Deleting unused archive files..."
  sudo rm *.tar.*

  echo "==> Adjusting ownership of build directory..."
  sudo chown -R build .

  echo "==> Build directory content"
  ls -lah .

  echo "==> Build subdirectory sizes"
  du -h -d 1

  echo "==> Added --noextract --nodeps to build arguments"
  BUILD_ARGUMENTS="${BUILD_ARGUMENTS} --noextract --nodeps"
}

# build stage with timeout
build_stage() {
  echo "==> Building package..."
  echo "==> Using timestamp $(cat /etc/buildtime)"

  SOURCE_DATE_EPOCH=$(cat /etc/buildtime) timeout -k 10m -s SIGTERM "${TIMEOUT}m" makepkg ${BUILD_ARGUMENTS}

  EXIT_CODE="${?}"

  if ! (( ${EXIT_CODE} ))
  then
    echo "==> Build successful"
  elif [[ "${EXIT_CODE}" == "124" ]] # https://www.gnu.org/software/coreutils/manual/html_node/timeout-invocation.html#timeout-invocation
  then
    echo "==> Build timed out"
  else
    echo "==> Build failed with ${EXIT_CODE}"

    exit ${EXIT_CODE}
  fi

  echo "==> Build directory content"
  ls -lah /home/build

  echo "==> Build subdirectory sizes"
  sudo du -hd 1
}

# unpack files from previous stage
if [[ -d "/mnt/input" && -f "/mnt/input/progress.tar.zst" ]]
then
  unpack_stage
fi

# fix permissions
sudo chown -R build .

build_stage

# if package built, move to /mnt/output
if compgen -G "*.pkg.tar.xz" > /dev/null
then
  echo "==> Successfully built package"

  mkdir output -p

  if [[ -d "/mnt/output" ]]; then
    echo "==> Moving package to output directory..."
    sudo mv *.pkg.tar.xz /mnt/output
  else
    echo "==> Output directory does not exist"
  fi
fi

# pack the stage files
if [[ -d "/mnt/progress" ]]; then
  echo "==> Found progress directory, compressing current build progress"

  echo "==> Creating archive of progress..."
  tar caf progress.tar.zst src/ --remove-file -H posix --atime-preserve

  echo "==> Moving archive to progress directory..."
  sudo mv progress.tar.zst /mnt/progress
else
  echo "==> Progress directory does not exist, exiting"
fi
