#!/bin/bash

set -eu

validator="$(fly5 -t cc validate-pipeline -c ci/config/pipelines/aws-prod/deploy-pipeline.yml)"

if [[ $validator != *"looks good"* ]]; then
    command || exit 1
fi

