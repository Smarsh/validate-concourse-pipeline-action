#!/bin/bash

set -eu

fly --target "${CONCOURSE_TEAM}" login \
  --concourse-url "${CONCOURSE_URL}" \
  --team-name "${CONCOURSE_TEAM}" \
  --username "${CONCOURSE_USERNAME}" \
  --password "${CONCOURSE_PASSWORD}"



fly -t ${CONCOURSE_TEAM} validate-pipeline -c ${PIPELINE_CONFIG}

