#!/bin/bash

set -e

cleanup=(tmp.yml file_paths.yml unique_file_paths.yml names.yml test.csv baddies.yml jobs.yml paths.yml)
for file in ${cleanup[@]}; do
  if [[ -f $file ]]; then
    rm $file
  fi
done

if [ "$HANDLEBARS" ] &&  ! [ "$ALL_ENVS" ] ; then
  ./bin/generate $ENVIRONMENT_NAME
fi

# colors for the message
red=$'\e[1;31m'
white=$'\e[0m'
yellow=$'\e[0;33m'
green=$'\033[0;32m'
checkmark=$'\xE2\x9C\x94'

tmp_files=()
vars_file=''
if [[ "${VAR_FILES}"  ]]; then
  files=`echo $VAR_FILES | jq -r .[]`
  for file in $files; do
    vars_file="$vars_file -l $file"
  done
fi

if [[ $ALL_ENVS ]]; then
  env_array=()
  yml_files=$(find ci/vars -type f -name '*.yml' \! -name '*template_vars*' \! -name '*common*' -exec basename {} \;)
  for f in $yml_files
  do
    env_array+=("${f%.*}")
  done

  for e in "${env_array[@]}"
  do
    ./bin/generate "$e"
    echo -e "${yellow}Validating $PIPELINE_CONFIG with fly validate...$white"
    fly validate-pipeline -o -c ${PIPELINE_CONFIG} ${vars_file} >> "$e"_tmp.yml
    tmp_files+=("$e"_tmp.yml)
  done

fi

if [[ "${tmp_files[@]}" -eq 0 ]]; then
  echo -e "${yellow}Validating $PIPELINE_CONFIG with fly validate...$white\n"
  fly validate-pipeline -o -c ${PIPELINE_CONFIG} ${vars_file} >> tmp.yml

  # Validates the yaml format
  yq v tmp.yml

  echo -e "\n${yellow}Validating task file paths...$white\n"

  # Gets the value for any file key in the pipeline yaml
  yq r tmp.yml jobs[*].plan[*].file | grep -o 'ci.*' >> file_paths.yml

  # Gets the path for every file key in the pipeline yaml
  yq r --printMode p tmp.yml jobs[*].plan[*].file >> paths.yml

  # Shortens the file_path to ci/*
  cat paths.yml | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> jobs.yml

  # Gets the job names from all jobs in the jobs.yml
  while IFS= read -r line; do
    yq r tmp.yml "$line.name" >> names.yml;
  done < jobs.yml

  # Combines the names.yml and file_paths.yml into one file with a "," delimiter
  paste -d ","  names.yml file_paths.yml > test.csv

  # Using the delimiter it checks if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the file_path, and will put and non existing file in the baddies.yml
  while IFS="," read -r name file; do
    if [ ! -f "${file}" ]; then
      echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
      echo "$file" >> baddies.yml
    fi
  done < test.csv

  echo -e "\n${yellow}Validating that task scripts are executable...$white\n"

  # get unique task.yml's and get the task script they are calling to check if they are executable
  perl -ne 'print if ! $a{$_}++' file_paths.yml >> unique_file_paths.yml

  while IFS= read -r file; do
    if [[ -f ${file} ]]; then
      if [[ $file == $PIPELINE_CONFIG ]]; then
        continue
      fi
      task=`yq r $file [*].path | grep -o 'ci.*'`
      if [[ ! -x ${task} ]]; then
        echo -e "$red$task$white is not executable"
        echo "$task" >> baddies.yml
      fi
    fi
  done < unique_file_paths.yml

  # If the baddies.yml exists then it will exit with an error.\
  if [[ -f baddies.yml ]]; then
  exit 1
  fi

  echo -e "Looks good $green$checkmark$white"
  exit 0

else
    file_paths=()
    paths=()
    jobs=()
    names=()
    csv_files=()
    baddies_array=()
    unique_paths=()
    for f in "${tmp_files[@]}"
    do
      yq v "$f"

      # Gets the value for any file key in the pipeline yaml
      yq r "$f" jobs[*].plan[*].file | grep -o 'ci.*' >> "${f%.*}"_file_paths.yml
      file_paths+=("${f%.*}"_file_paths.yml)

      # Gets the path for every file key in the pipeline yaml
      yq r --printMode p "$f" jobs[*].plan[*].file >> "${f%.*}"_paths.yml
      paths+=("${f%.*}"_paths.yml)

      for p in "${paths[@]}"
      do
        # Shortens the file_path to ci/*
        cat "$p" | grep -o 'jobs.\(\[\d]\|\[\d\d]\)' >> "${f%.*}"_jobs.yml
        jobs+=("${f%.*}"_jobs.yml)
      done

      for j in "${jobs[@]}"
      do
        # Gets the job names from all jobs in the jobs.yml
        while IFS= read -r line; do
          yq r "$f" "$line.name" >> "${f%.*}"_names.yml;
          names+=("${f%.*}"_names.yml)
        done < "$j"
      done

      for n in "${names[@]}"
      do
        for fp in "${file_paths[@]}"
        do
          # Combines the names.yml and file_paths.yml into one file with a "," delimiter
          paste -d ","  "$n" "$fp" > "${f%.*}".csv
          csv_files+=("${f%.*}".csv)
        done
      done

      for csv in "${csv_files[@]}"
      do
        # Using the delimiter it checks if the file does not exist, and if it doesn't exits will then alert that the Job Name does not have the file_path, and will put and non existing file in the baddies.yml
        while IFS="," read -r name file; do
          if [ ! -f "${file}" ]; then
            echo -e "$red$name$white references a path that doesn't exist:\n ----- ${file} does not exist"
            echo "$file" >> "${f%.*}"_baddies.yml
            baddies_array+=("${f%.*}"_baddies.yml)
          fi
        done < "$csv"

      done

      echo -e "\n${yellow}Validating that task scripts are executable...$white\n"

      for fs in "${file_paths[@]}"
      do
        # get unique task.yml's and get the task script they are calling to check if they are executable
        perl -ne 'print if ! $a{$_}++' "$fs" >> "${f%.*}"_unique_paths.yml
        unique_paths+=("${f%.*}"_unique_paths.yml)
      done

      for u in "${unique_paths[@]}"
      do
        while IFS= read -r file; do
          if [[ -f ${file} ]]; then
            if [[ $file == $PIPELINE_CONFIG ]]; then
              continue
            fi
            task=`yq r $file [*].path | grep -o 'ci.*'`
            if [[ ! -x ${task} ]]; then
              echo -e "$red$task$white is not executable"
              echo "$task" >> "${f%.*}"_baddies.yml
              baddies_array+=("${f%.*}"_baddies.yml)
            fi
          fi
        done < "$u"

      done

      if ! [[ "${baddies_array[@]}" -eq 0 ]]; then
          exit 1
      fi

      echo -e "Looks good $green$checkmark$white"
      exit 0

    done
fi
