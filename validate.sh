#!/bin/bash

set -e

if [[ $HANDLEBARS ]]; then
  ./bin/generate $ENVIRONMENT_NAME
fi

vars_file=''
if [[ "${VAR_FILES}"  ]]; then
  files=`echo $VARS_FILES | jq -r .[]`
  for file in ${files[@]}; do
    vars_file="$vars_file -l $file"
  done
fi

echo "${vars_file}"

fly validate-pipeline -c "${PIPELINE_CONFIG}" "${vars_file}"

# Validates the yaml format
yq v "${PIPELINE_CONFIG}"

# colors for the message
red=$'\e[1;31m'
white=$'\e[0m'

# Gets the value for any file key in the pipeline yaml
yq r "${PIPELINE_CONFIG}" jobs[*].plan[*].file | grep -o 'ci.*' >> file_paths.yml

# Gets the path for every file key in the pipeline yaml
yq r --printMode p "${PIPELINE_CONFIG}" jobs[*].plan[*].file >> paths.yml

# Shortens the file_path to ci/*
cat paths.yml | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> jobs.yml

# Gets the job names from all jobs in the jobs.yml
while IFS= read -r line; do
  yq r "${PIPELINE_CONFIG}" "$line.name" >> names.yml;
done < jobs.yml

# Combines the names.yml and file_paths.yml into one file with a "," delimiter
paste -d ","  names.yml file_paths.yml > test.csv

# Using the delimiter it checkes if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the file_path, and will put and non existing file in the baddies.yml
while IFS="," read -r name file; do
    if [ ! -f "${file}" ]; then
      echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
      echo "$file" >> baddies.yml
    fi
    if [[ -f "${file}" && ! -x "${file}" ]]; then
      echo "$file is not executable"
      echo "$file" >> baddies.yml
    fi
done < test.csv


# If the baddies.yml exists then it will exit with an error.\
if [ -f baddies.yml ]; then
  exit 1
fi
