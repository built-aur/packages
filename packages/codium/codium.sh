#!/bin/sh
set -e

ELECTRON_RUN_AS_NODE=1 exec electron /usr/lib/codium/out/cli.js /usr/lib/codium/codium.js "$@"
