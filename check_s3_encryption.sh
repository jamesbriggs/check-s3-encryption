#!/bin/bash

# Program: check_s3_encryption.sh
# Purpose: check for unencrypted AWS S3 buckets and report and/or return exit status
# Author: James Briggs, USA
# Version: 1.0
# Env: bash
# Usage: check_s3_encryption.sh
# Link: https://github.com/jamesbriggs/check-s3-encryption
# Note: if report=1 (see below), the unencrypted buckets report is printed in CSV format

###
### start of user settings
###

report=1 # print summary report

bash4=1 # only needed for blacklist feature. On Mac OS X, do `brew install bash` and update the shebang line at top of script to /usr/local/bin/bash if you need a blacklist.

encrypt=0
max_encrypt=1000000000 # bytes

###
### end of user settings
###

trap "echo Exited!; exit;" SIGINT SIGTERM

cmd_out=`aws --version`
if ! [[ $cmd_out =~ aws-cli ]]; then
   echo "error: aws cli not installed"
   exit 1
fi

if [[ "$encrypt" -eq "1" ]]; then
   cmd_out=`s3cmd --version`
   if ! [[ $cmd_out =~ version ]]; then
      echo "error: s3cmd not installed"
      exit 1
   fi
fi

total=0
total_unenc=0
pct_unenc=0
sz=0

# first blacklist buckets that are too large (> 1 TB for example)
if [[ "$bash4" -eq "1" ]]; then
   declare -A blacklist

   for i in \
      "dummy1" \
      "dummy2" \
      ; do

      blacklist[$i]="9"
   done
fi

for i in `aws s3api list-buckets --query "Buckets[].Name" --output text`; do
   total=$((total + 1))

   if [[ "$bash4" -eq "1" ]]; then
      if [[ "9" -eq  "${blacklist[$i]}" ]]; then
         echo "blacklisted: $i ..."
         continue
      fi
   fi

   aws s3api get-bucket-encryption --bucket  $i >/dev/null 2>&1
   ret=$?
   if [ "$ret" -ne "0" ]; then

      if [ "$encrypt" -ne "0" ]; then
         sz=`s3cmd du s3://$i | cut -f1 -d ' '`
         if [ "$sz" -lt "$max_encrypt" ]; then
             echo "encrypting $i $sz bytes ..."
             # mark bucket as an encrypted bucket
             aws s3api put-bucket-encryption --bucket $i \
                --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
             # copy bucket to itself to encrypt old files with standard SSE AES256 encryption
             aws s3 cp s3://$i/ s3://$i/ --recursive --sse
         fi
      fi

      echo "$i,ret=$ret,$sz"
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

