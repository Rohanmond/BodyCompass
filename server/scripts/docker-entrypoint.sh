#!/bin/sh

set -eu

data_directory=${BODYCOMPASS_DATA_DIR:-/data}

if [ "$(id -u)" = "0" ]; then
    mkdir -p "$data_directory"
    chown node:node "$data_directory"
    exec setpriv --reuid=node --regid=node --init-groups "$@"
fi

if [ ! -w "$data_directory" ]; then
    echo "BodyCompass cannot write to $data_directory. On Railway, set RAILWAY_RUN_UID=0 so the entrypoint can prepare the volume and then drop privileges." >&2
    exit 1
fi

exec "$@"
