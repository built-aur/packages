#!/bin/bash

free_space() {
  case "${1}" in
    "unreal-engine")
      echo "Free space..."
      # rm boost & tools
      sudo rm -rf "/usr/local/share/boost"
      # rm dotnet
      sudo rm -rf '/usr/share/dotnet'
      # rm android sdk
      sudo rm -rf "${ANDROID_SDK_ROOT}"
      sudo rm -rf '/usr/local/lib/android'
      # rm swift
      sudo rm -rf "${SWIFT_PATH}"
      sudo rm -rf '/usr/share/swift'

      # Remove docker image
      docker rmi $(docker image ls -aq)
      ;;
    esac
}

if [ "${github_event}" != "workflow_dispatch" ]
then
  BASE_COMMIT=$(jq --raw-output .pull_request.base.sha "${GITHUB_EVENT_PATH}")
  OLD_COMMIT=$(jq --raw-output .commits[0].id "${GITHUB_EVENT_PATH}")
  HEAD_COMMIT=$(jq --raw-output .commits[-1].id "${GITHUB_EVENT_PATH}")
  if [ "${BASE_COMMIT}" = "null" ]
  then
    # Single-commit push
    if [ "${OLD_COMMIT}" = "${HEAD_COMMIT}" ]
    then
      echo "Processing commit: ${HEAD_COMMIT}"
      CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "${HEAD_COMMIT}")

    # Multi-commit push
    else
      OLD_COMMIT="${OLD_COMMIT}~1"
      echo "Processing commit range: ${OLD_COMMIT}..${HEAD_COMMIT}"
      CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "${OLD_COMMIT}" "${HEAD_COMMIT}")
    fi

  # Pull requests
  else
    echo "Processing pull request #$(jq --raw-output .pull_request.number "${GITHUB_EVENT_PATH}"): ${BASE_COMMIT}..HEAD"
    CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r "${BASE_COMMIT}" "HEAD")
  fi

  # Process tag '%ci:no-build' that may be added as line to commit message.
  # Forces CI to cancel current build with status 'passed'.
  if grep -qiP '^\s*%ci:no-build\s*$' <(git log --format="%B" -n 1 "HEAD")
  then
    echo "[!] Force exiting as tag '%ci:no-build' was applied to HEAD commit message."
    exit 0
  fi

  # Parse changed files and identify new packages and deleted packages.
  # Create lists of those packages that will be passed to upload job for
  # further processing.
  while read -r file
  do
    if [ -d ${file} ]
    then
      file="${file}/PKGBUILD"
    fi

    # This file does not belong to a package, so ignore it
    if ! [[ ${file} == packages/* ]]
    then
      continue
    fi

    if [[ ${file} =~ ^packages/([.a-z0-9+-]*)/.*$ ]]
    then
      # package, check if it was deleted or updated
      pkg=${BASH_REMATCH[1]}
      if [ ! -d "packages/${pkg}" ]; then
        echo "${pkg}" >> ./deleted_packages.txt
      else
        free_space "${pkg}"
        echo "${pkg}" >> ./built_packages.txt
      fi
    fi

  done<<<${CHANGED_FILES}
else
  for pkg in ${github_inputs_packages}
  do
    free_space "${pkg}"
    echo "${pkg}" >> ./built_packages.txt
  done
fi

if [ -f ./built_packages.txt ]
then
  # Fix so that lists do not contain duplicates
  uniq ./built_packages.txt > ./built_packages.txt.tmp
  mv ./built_packages.txt.tmp ./built_packages.txt

  printf "\nPackages to build:\n"
  cat --number built_packages.txt
fi

if [ -f ./deleted_packages.txt ]
then
  # Fix so that lists do not contain duplicates
  uniq ./deleted_packages.txt > ./deleted_packages.txt.tmp
  mv ./deleted_packages.txt.tmp ./deleted_packages.txt

  printf "\nDeleted packages:\n"
  cat --number deleted_packages.txt
fi
