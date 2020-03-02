#!/bin/bash

set -eu

red=$'\e[1;31m'
white=$'\e[0m'


yq r --printMode p "${PIPELINE_CONFIG}" jobs[*].plan[*].file >> paths.yml
while IFS= read -r line; do
    FILE="$(yq r ${PIPELINE_CONFIG} $line)"
    job_name="$(yq r ${PIPELINE_CONFIG} ${line:0:8}.name)"
    if [ ! -f "${FILE:17}" ]; then
        echo -e "$red$job_name$white has a file with an incorrect path:\n ----- ${FILE:17} does not exist"
        echo "$FILE" >> baddies.yml
    fi
done < paths.yml

if [ -f baddies.yml ]; then
  exit 1
fi