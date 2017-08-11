#!/bin/bash

# S3 bucket to upload to
bucket=${bucket:-test-discourse-backups}

# Directory to get the backups from
backup_dir=${backup_dir:-/var/discourse/discourse_docker/shared/standalone/backups/default}

# Number of days to keep each backup in the bucket
days_to_keep=${days_to_keep:-30}

# s3cmd binary to use
s3cmd_bin=${s3cmd_bin:-s3cmd}

# Upload new backups to s3
echo "Uploading new backups"
for file in ${backup_dir}/* ; do
    # Get the file name
    name_with_extension="$(basename $file)"

    # Check if the file already exists in s3, if it does, move on to the next
    # file
    files_in_s3="$($s3cmd_bin ls s3://${bucket})"
    if $( echo $files_in_s3 | grep "$name_with_extension" 2>&1 > /dev/null) ; then
        continue
    fi

    # Get the date the backup was made
    name="$(basename $file | cut -d . -f1)"
    fields="$(echo $name | awk -F '-' '{print NF}')"
    year="$(echo $name | cut -d '-' -f$(($fields-4)))"
    month="$(echo $name | cut -d '-' -f$(($fields-3)))"
    day="$(echo $name | cut -d '-' -f$(($fields-2)))"
    time_from_epoch="$(date --date="$year-$month-$day" +%s)"
    current_from_epoch="$(date +%s)"

    # Compare the date the backup was made to today, if it is less than
    # $days_to_keep days, then upload it
    diff="$(($current_from_epoch - $time_from_epoch))"
    if [[ $diff -le $(($days_to_keep * 86400)) ]] ; then
        echo "Uploading $file to $bucket"
        $s3cmd_bin put $file s3://${bucket}/${name_with_extension} 2> /dev/null
    fi
done

# Delete old backups in s3
echo "Deleting old backups"
for file in $($s3cmd_bin ls s3://${bucket} | awk '{print $4}') ; do
    # Get the date the backup was made
    name="$(basename $file | cut -d . -f1)"
    fields="$(echo $name | awk -F '-' '{print NF}')"
    year="$(echo $name | cut -d '-' -f$(($fields-4)))"
    month="$(echo $name | cut -d '-' -f$(($fields-3)))"
    day="$(echo $name | cut -d '-' -f$(($fields-2)))"
    time_from_epoch="$(date --date="$year-$month-$day" +%s)"
    current_from_epoch="$(date +%s)"
    # Compare the date the backup was made to today, if it is more than
    # $days_to_keep days, then delete it
    diff="$(($current_from_epoch - $time_from_epoch))"
    if [[ $diff -gt $(($days_to_keep * 86400)) ]] ; then
        echo "Deleting $file from $bucket"
        $s3cmd_bin rm $file 2> /dev/null
    fi
done

#############################
# Managing backups manually #
#############################

# In order to list the backups available in s3, run `s3cmd ls s3://$bucket/`
# In order to download a specific bucket, run:
# `s3cmd get s3://$bucket/$backup_name destination`
