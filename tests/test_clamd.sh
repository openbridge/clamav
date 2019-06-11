#!/usr/bin/env bash

set -o xtrace
set -o nounset
set -o pipefail

source /network

PROCESS_ID=$(pidof clamd)
if [[ -z $PROCESS_ID ]]; then
    echo "ERROR: Clamd process is not running. Start..."
    hipchat -i "ERROR: Clamd process was not running. Starting..." -l "CRITICAL"
    # Start Clamd
    runclam="clamd -c /etc/clamd.conf" && bash -c "${runclam}"
fi

exit 0
