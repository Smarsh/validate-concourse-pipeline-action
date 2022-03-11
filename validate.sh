#!/bin/bash

set -e

cleanup=(tmp.yml file_paths.yml unique_file_paths.yml names.yml test.csv baddies.yml jobs.yml paths.yml)
for file in ${cleanup[@]}; do
  if [[ -f $file ]]; then
    rm $file
  fi
done

if [[ $MULTI_REPO == true ]]; then
  pushd $PIPELINE_REPOSITORY
fi

if [[ $PIPELINE_REPOSITORY ]]; then
  pipeline_path="${PIPELINE_REPOSITORY}"
else
  pipeline_path=""
fi

# colors for the message
export red=$'\e[1;31m'
export white=$'\e[0m'
export yellow=$'\e[0;33m'
export green=$'\033[0;32m'
export checkmark=$'\xE2\x9C\x94'

if [[ -z  $ENV_LIST ]]; then
  echo "list of environments has to be given $red$checkmark$white"
fi

for ENVIRONMENT_NAME in $ENV_LIST; do

    if [[ $HANDLEBARS == true ]]; then
      ./bin/generate $ENVIRONMENT_NAME
      pushd $GITHUB_WORKSPACE
    fi

  /checkenv.sh
done