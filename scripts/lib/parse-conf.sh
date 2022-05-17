#!/bin/bash

parse-conf() {
  . "${1}/built.conf"

  echo "local AUR_NAME=${AUR_NAME}"
  echo "local AUR_VERSION=${AUR_VERSION}"
  echo "local GITHUB_REPO=${GITHUB_REPO}"
  echo "local GITHUB_TAG=${GITHUB_TAG}"
  echo "local NPM=${NPM}"
}
