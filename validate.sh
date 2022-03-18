#!/bin/bash

set -e

# cleanup=(file_paths.yml unique_file_paths.yml names.yml test.csv baddies.yml jobs.yml paths.yml)
# for file in ${cleanup[@]}; do
#   if [[ -f $file ]]; then
#     rm $file
#   fi
# done

  if [[ -d result_dir ]]; then
    rm -r result_dir
  fi

#creating the result directory
mkdir result_dir

if [[ $MULTI_REPO == true ]]; then
  echo " entering into pipeline repo"
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
export crossmark=$'\xE2\x9D\x8C'

if [[ -z  $ENV_LIST ]]; then
  echo "list of environments has to be given $red$crossmark$white"
fi

checkenv(){
  echo " entering into github workspace"
  pushd $GITHUB_WORKSPACE
  vars_file=''
  if [[ "${VAR_EXTS}"  ]]; then
    extentsions=`echo $VAR_EXTS | jq -r .[]`
    for extension in $extentsions; do
      file_path="${pipeline_path}/ci/vars/$1$extension"
      echo "file path is : $file_path"
      vars_file="$vars_file -l $file_path"

      cuefile="$file_path.cue"
      if [[ -f "$cuefile" ]]; then
        echo "cue vet $cuefile $file_path"
        cue vet $cuefile $file_path
      else
        echo "cue file not found: $cuefile"
      fi
    done
  fi

    echo -e "${yellow}Validating $PIPELINE_CONFIG with fly validate...$white\n"

    fly validate-pipeline -o -c "${pipeline_path}/${PIPELINE_CONFIG}" "${vars_file}" >> result_dir/$1.yml
}

validate_tasks(){
  pushd $GITHUB_WORKSPACE
    # Validates the yaml format
    pushd result_dir
    yq v $2

    echo -e "\n${yellow}Validating task file paths...$white\n"

    yq r $2 jobs[*].plan[*].file >> $1_file_paths.yml

    # get unique task.yml's
    perl -ne 'print if ! $a{$_}++' $1_file_paths.yml >> $1_unique_file_paths.yml

    # Gets the path for every file key in the pipeline yaml
    yq r --printMode p $2 jobs[*].plan[*].file >> $1_paths.yml

    # Gets the value for any file key in the pipeline yaml
    cat $1_paths.yml | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> $1_jobs.yml

    # Gets the job names from all jobs in the jobs.yml
    while IFS= read -r line; do
      yq r $2 "$line.name" >> $1_names.yml;
    done < $1_jobs.yml

    # Combines the names.yml and unique_file_paths.yml into one file with a "," delimiter
    paste -d ","  $1_names.yml $1_unique_file_paths.yml > $1_test.csv


    # Using the delimiter it checkes if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the
    # file_path, and will put and non existing file in the baddies.yml
    while IFS="," read -r name file; do
        if [ ! -f "${file}" ] && [[ ${file} != interpolated-versions* ]] && [[ ${file} != versions-ui_portal_* ]] && [[ ! (${file} =~ event-logging-git/*) ]]  && [[ ! (${file} =~ insights-jobs-app-git/*) ]]  && [[ ! (${file} =~ git-properties-*/*) ]] && [[ ! (${file} =~ ea-policy-evaluation-service-git/*) ]]  && [[ ! (${file} =~ ea-ediscovery-api-git/*) ]]  && [[ ${file} != versions-*/.ref ]] && [[ ${file} != */version ]] && [[ ${file} != ipList/ipList.txt ]] && [[ ${file} != platform-automation-tasks/tasks/credhub-interpolate.yml ]]; then
          echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
          echo "$file" >> baddies.yml
        fi
    done < $1_test.csv

    echo -e "\n${yellow}Validating that task scripts are executable...$white\n"

    # use unique_file_paths to get the task script they are calling to check if they are executable
    while IFS= read -r file; do
      if [[ -f ${file} ]]; then
        if [[ $file == $PIPELINE_CONFIG ]]; then
          continue
        fi
        task=`yq r $file [*].path`
        if ([[ -f ${task} ]] && [[ ! -x ${task} ]]); then
          echo -e "$red$task$white is not executable"
          echo "$task" >> baddies.yml
        fi
      fi
    done < $1_unique_file_paths.yml

    # If the baddies.yml exists then it will exit with an error.\
    if [[ -f baddies.yml ]]; then
      echo "echoing baddies.yml"
      echo -e "$1 Failed with error $red$crossmark$white"
      cat baddies.yml
      exit 1
    fi

    echo -e "$1 Looks good $green$checkmark$white"
}

for ENVIRONMENT_NAME in $ENV_LIST; do
    if [[ $HANDLEBARS == true ]]; then
      ./bin/generate $ENVIRONMENT_NAME
    fi
    checkenv "$ENVIRONMENT_NAME"
done

for filename in result_dir/*.yml; do
    validate_tasks "$filename"
done

# echo " entering into github workspace"
# pushd $GITHUB_WORKSPACE
# ENV_ARR=($ENV_LIST)
# # ARR_LEN=`echo ${ENV_ARR[@]}`
# # while [ $ARR_LEN -gt 0 ]
#   for ENVIRONMENT_NAME in ${ENV_ARR[@]}; do
#     echo "starting checks for environment $ENVIRONMENT_NAME"
#     checkenv &
#     sleep 10s
#   done

FAIL=0
for job in `jobs -p`
do
    echo $job
    wait $job || let "FAIL+=1"
done
if [ "$FAIL" == "0" ];
then
    echo -e "All the environment checks are successful!!! $green$checkmark$white"
else
    echo -e "One or mor environment check is failing!!! $red$crossmark$white"
    exit 1
fi