#!/bin/bash

bucket=${bucket:-test-discourse-backups}

backup_dir=${backup_dir:-/var/discourse/discourse_docker/shared/standalone/backups/default}

days_to_keep=${days_to_keep:-30}

s3cmd_bin=${s3cmd_bin:-s3cmd}

echo "Uploading new backups"
for file in ${backup_dir}/* ; do
    name_with_extension="$(basename $file)"
    files_in_s3="$($s3cmd_bin ls s3://${bucket})"
    if $( echo $files_in_s3 | grep "$name_with_extension" 2>&1 > /dev/null) ; then
        continue
    fi
    name="$(basename $file | cut -d . -f1)"
    fields="$(echo $name | awk -F '-' '{print NF}')"
    year="$(echo $name | cut -d '-' -f$(($fields-4)))"
    month="$(echo $name | cut -d '-' -f$(($fields-3)))"
    day="$(echo $name | cut -d '-' -f$(($fields-2)))"
    time_from_epoch="$(date --date="$year-$month-$day" +%s)"
    current_from_epoch="$(date +%s)"
    diff="$(($current_from_epoch - $time_from_epoch))"
    if [[ $diff -le $(($days_to_keep * 86400)) ]] ; then
        echo "Uploading $file to $bucket"
        $s3cmd_bin put $file s3://${bucket}/${name_with_extension} 2> /dev/null
    fi
done

echo "Deleting old backups"
for file in $($s3cmd_bin ls s3://${bucket} | awk '{print $4}') ; do
    name="$(basename $file | cut -d . -f1)"
    fields="$(echo $name | awk -F '-' '{print NF}')"
    year="$(echo $name | cut -d '-' -f$(($fields-4)))"
    month="$(echo $name | cut -d '-' -f$(($fields-3)))"
    day="$(echo $name | cut -d '-' -f$(($fields-2)))"
    time_from_epoch="$(date --date="$year-$month-$day" +%s)"
    current_from_epoch="$(date +%s)"
    diff="$(($current_from_epoch - $time_from_epoch))"
    if [[ $diff -gt $(($days_to_keep * 86400)) ]] ; then
        echo "Deleting $file from $bucket"
        $s3cmd_bin rm $file 2> /dev/null
    fi
done
