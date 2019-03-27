#!/bin/bash

# Program: check_s3_encryption.sh
# Purpose: check for unencrypted AWS S3 buckets and report and/or return exit status
# Author: James Briggs, USA
# Env: bash
# Usage: check_s3_encryption.sh
# Note: if report=1 (see below), the unencrypted buckets report is printed in CSV format

###
### start of user settings
###

report=1

###
### end of user settings
###

total=0
total_unenc=0
pct_unenc=0

trap "echo Exited!; exit;" SIGINT SIGTERM

for i in `aws s3api list-buckets --query "Buckets[].Name" --output text`; do
   total=$((total + 1))
   aws s3api get-bucket-encryption --bucket  $i >/dev/null 2>&1
   ret=$?
   if [ "$ret" -ne "0" ]; then
      echo "$i,ret=$ret"
      total_unenc=$((total_unenc + 1))
   fi
   sleep 1 # rate-limiting to avoid AWS API throttling (optional)
done

if [ "$report" -eq "1" ]; then
   if [ "$total" -ne "0" ]; then
      pct_unenc=$((100 * total_unenc / $total))
   fi

   echo
   echo "total buckets=$total"
   echo "total unencrypted buckets=$total_unenc"
   echo "percent unencrypted=$pct_unenc%"
fi

trap - SIGINT SIGTERM

if [ "$total_unenc" -ne "0" ]; then
   exit 1
else
   exit 0
fi

