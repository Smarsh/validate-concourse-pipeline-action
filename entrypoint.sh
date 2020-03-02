#!/bin/bash

set -eu

credhub login --skip-tls-validation

CONCOURSE_PASSWORD="$(credhub get -q -n /concourse/${CONCOURSE_TEAM}/ci-user-password)"

fly --target "${CONCOURSE_TEAM}" login \
  --concourse-url "${CONCOURSE_URL}" \
  --team-name "${CONCOURSE_TEAM}" \
  --username "${CONCOURSE_USERNAME}" \
  --password "${CONCOURSE_PASSWORD}"

fly -t ${CONCOURSE_TEAM} validate-pipeline -c ${PIPELINE_CONFIG}

red=$'\e[1;31m'
white=$'\e[0m'


yq r --printMode p "${PIPELINE_CONFIG}" jobs[*].plan[*].file >> paths.yml
while IFS= read -r line; do
    FILE="$(yq r ${PIPELINE_CONFIG} $line)"
    job_name="$(yq r ${PIPELINE_CONFIG} ${line:0:8}.name)"
    if [ ! -f "${FILE:17}" ]; then
        echo -e "$red $job_name has a file with an incorrect path:\n ----- ${FILE:17} does not exist$white"
        echo "$FILE" >> baddies.yml
    fi
done < paths.yml

if [ -f baddies.yml ]; then
  exit
fi