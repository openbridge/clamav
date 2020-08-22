#!/usr/bin/env bash
set -o xtrace
set -o nounset
set -o pipefail

source /network

{
      echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*
'
} | tee /tests/virus/eicar.com

for i in /tests/virus/*; do

VIRUS_TEST=$(clamdscan --stream ${i} | grep -o FOUND)

  if [ $VIRUS_TEST == "FOUND" ]; then
      echo "SUCCESS: Clamd working and detecting our test file (${i})"
  else
      echo "FAILED: Clamd is not detecting our test virus file (${i})"
      exit 1
  fi

done

exit 0
