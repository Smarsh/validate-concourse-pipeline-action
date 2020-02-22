#!/bin/bash

set -eu

fly --target "${CONCOURSE_TEAM}" login \
  --concourse-url "${CONCOURSE_URL}" \
  --team-name "${CONCOURSE_TEAM}" \
  --username "${CONCOURSE_USERNAME}" \
  --password "${CONCOURSE_PASSWORD}"


for file in ci/config/pipelines/aws-prod/*; do 

    validator="$(fly -t ${CONCOURSE_TEAM} validate-pipeline -c ${file} )"

    if [[ $validator != *"looks good"* ]]; then
        command || exit 1
    else echo "Passed"
    fi
done
