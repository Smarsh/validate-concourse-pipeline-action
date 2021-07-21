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
  pipeline_path="${PIPELINE_REPOSITORY}/"
else
  pipeline_path=""
fi

if [[ $HANDLEBARS == true ]]; then
  ./bin/generate $ENVIRONMENT_NAME
  pushd $GITHUB_WORKSPACE
fi

vars_file=''
if [[ "${VAR_FILES}"  ]]; then
  files=`echo $VAR_FILES | jq -r .[]`
  for file in $files; do
    vars_file="$vars_file -l ${pipeline_path}/$file"
  done
fi


# colors for the message
red=$'\e[1;31m'
white=$'\e[0m'
yellow=$'\e[0;33m'
green=$'\033[0;32m'
checkmark=$'\xE2\x9C\x94'

echo -e "${yellow}Validating $PIPELINE_CONFIG with fly validate...$white\n"
pwd

fly validate-pipeline -o -c "${pipeline_path}/${PIPELINE_CONFIG}" "${vars_file}" >> tmp.yml

# Validates the yaml format
yq v tmp.yml

echo -e "\n${yellow}Validating task file paths...$white\n"

# Shortens the file_path to ci/* or keeps whole path

if [[ $MULTI_REPO == true ]]; then
  yq r tmp.yml jobs[*].plan[*].file >> file_paths.yml
else
  # yq r tmp.yml jobs[*].plan[*].file | grep -o 'ci.*' >> file_paths.yml
  yq r tmp.yml jobs[*].plan[*].file >> file_paths.yml
fi
echo "file_paths.yml"
cat file_paths.yml

# get unique task.yml's
perl -ne 'print if ! $a{$_}++' file_paths.yml >> unique_file_paths.yml
echo "unique_file_paths.yml"
cat unique_file_paths.yml


# Gets the path for every file key in the pipeline yaml
yq r --printMode p tmp.yml jobs[*].plan[*].file >> paths.yml
echo "paths.yml"
cat paths.yml

# Gets the value for any file key in the pipeline yaml
cat paths.yml | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> jobs.yml
echo "jobs.yml"
cat jobs.yml

# Gets the job names from all jobs in the jobs.yml
while IFS= read -r line; do
  yq r tmp.yml "$line.name" >> names.yml;
done < jobs.yml
echo "jobs.yml again"
cat jobs.yml

# Combines the names.yml and unique_file_paths.yml into one file with a "," delimiter
paste -d ","  names.yml unique_file_paths.yml > test.csv
echo "test.csv"
cat test.csv
pwd

# Using the delimiter it checkes if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the file_path, and will put and non existing file in the baddies.yml
while IFS="," read -r name file; do
    if [ ! -f "${file}" ]; then
      echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
      echo "$file" >> baddies.yml
    fi
done < test.csv

echo "test.csv"
cat test.csv




echo -e "\n${yellow}Validating that task scripts are executable...$white\n"

# use unique_file_paths to get the task script they are calling to check if they are executable
while IFS= read -r file; do
  if [[ -f ${file} ]]; then
    if [[ $file == $PIPELINE_CONFIG ]]; then
      continue
    fi
    if [[ ${MULTI_REPO} == true ]]; then # if MULTI_REPO is true it will take the whole path of the task and expects to have the directories in the container
      task=`yq r $file [*].path`
    else
      # task=`yq r $file [*].path | grep -o 'ci.*'`
      task=`yq r $file [*].path`
    fi
    if ([[ -f ${task} ]] && [[ ! -x ${task} ]]); then
      echo -e "$red$task$white is not executable"
      echo "$task" >> baddies.yml
    fi
  fi
done < unique_file_paths.yml

# If the baddies.yml exists then it will exit with an error.\
if [[ -f baddies.yml ]]; then
  echo "echoing baddies.yml"
  cat baddies.yml
  exit 1
fi

echo -e "Looks good $green$checkmark$white"
exit 0
