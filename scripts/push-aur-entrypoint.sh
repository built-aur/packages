#!/bin/bash

set -o errexit -o pipefail -o nounset

echo '::group::Initializing SSH directory'
mkdir -pv /home/build/.ssh
touch /home/build/.ssh/known_hosts
cp -v /ssh_config /home/build/.ssh/config
chown -vR build:build /home/build
chmod -vR 600 /home/build/.ssh/*
echo '::endgroup::'

exec su -c 'bash -c ./scripts/publish-aur.sh' build
