  vars_file=''
  if [[ "${VAR_EXTS}"  ]]; then
    extentsions=`echo $VAR_EXTS | jq -r .[]`
    for extension in $extentsions; do
      file_path="${pipeline_path}/ci/vars/$ENVIRONMENT_NAME$extension"
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

    fly validate-pipeline -o -c "${pipeline_path}/${PIPELINE_CONFIG}" "${vars_file}" >> tmp.yml

    # Validates the yaml format
    yq v tmp.yml

    echo -e "\n${yellow}Validating task file paths...$white\n"

    yq r tmp.yml jobs[*].plan[*].file >> file_paths.yml

    # get unique task.yml's
    perl -ne 'print if ! $a{$_}++' file_paths.yml >> unique_file_paths.yml

    # Gets the path for every file key in the pipeline yaml
    yq r --printMode p tmp.yml jobs[*].plan[*].file >> paths.yml

    # Gets the value for any file key in the pipeline yaml
    cat paths.yml | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> jobs.yml

    # Gets the job names from all jobs in the jobs.yml
    while IFS= read -r line; do
      yq r tmp.yml "$line.name" >> names.yml;
    done < jobs.yml

    # Combines the names.yml and unique_file_paths.yml into one file with a "," delimiter
    paste -d ","  names.yml unique_file_paths.yml > test.csv

    # Using the delimiter it checkes if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the
    # file_path, and will put and non existing file in the baddies.yml
    while IFS="," read -r name file; do
        if [ ! -f "${file}" ] && [[ ${file} != interpolated-versions* ]] && [[ ${file} != versions-ui_portal_* ]] && [[ ! (${file} =~ event-logging-git/*) ]]  && [[ ! (${file} =~ insights-jobs-app-git/*) ]]  && [[ ! (${file} =~ git-properties-*/*) ]] && [[ ! (${file} =~ ea-policy-evaluation-service-git/*) ]]  && [[ ! (${file} =~ ea-ediscovery-api-git/*) ]]  && [[ ${file} != versions-*/.ref ]] && [[ ${file} != */version ]] && [[ ${file} != ipList/ipList.txt ]] && [[ ${file} != platform-automation-tasks/tasks/credhub-interpolate.yml ]]; then
          echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
          echo "$file" >> baddies.yml
        fi
    done < test.csv

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
    done < unique_file_paths.yml

    # If the baddies.yml exists then it will exit with an error.\
    if [[ -f baddies.yml ]]; then
      echo "echoing baddies.yml"
      cat baddies.yml
      exit 1
    fi

    echo -e "$ENVIRONMENT_NAME Looks good $green$checkmark$white"
    exit 0