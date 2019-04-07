#!/bin/bash

# Program: check_s3_encryption.sh
# Purpose: check for unencrypted AWS S3 buckets and report and/or return exit status
# Author: James Briggs, USA
# Version: 1.0
# Env: bash
# Usage: check_s3_encryption.sh
# Link: https://github.com/jamesbriggs/check-s3-encryption
# Warning from AWS when using encryption feature:
#    "Copying the object over itself removes settings for storage-class and website-redirect-location.
#    To maintain these settings in the new object, be sure to explicitly specify storage-class or 
#    website-redirect-location values in the copy request." This is mainly an issue for Public buckets,
#    which often have redirects and ACLs that are deleted when the encryption copy is applied. You can use the
#    skip_public_buckets=0 option if safety is important.
# Notes:
#
# - if report=1 (see below), the unencrypted buckets report is printed in CSV format
# - this program uses the AWS CLI for various S3 bucket-related operations. If you also use Terraform to manage S3 buckets, then
#   add this in the appropriate file locations:
#
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

###
### start of user settings
###

report=1 # print summary report

delay=0 # throttling interval between buckets (seconds)

# bash4 is only needed for blacklist feature.
# On Mac OS X, do `brew install bash` and update the shebang line at top of script to /usr/local/bin/bash if you need a blacklist.
bash4=1

encrypt=0
max_encrypt=100000000000 # bytes

# when encrypt=1 above, optionally skip public buckets to preserve the original redirects and permissions
skip_public_buckets=0

# blacklist buckets that are too large (> 1 TB for example) (optional)
if [[ "$bash4" -eq "1" ]]; then
   declare -A blacklist
   declare -r CH_FILLER="9"

   for i in \
      "dummy199" \
      "dummy299" \
      ; do

      blacklist[$i]=$CH_FILLER
   done
fi

###
### end of user settings
###

trap "echo Exited!; exit;" SIGINT SIGTERM

dt=`/bin/date +"%Y-%m-%d"`
MB=1000000

cmd_out=`aws --version 2>&1`
if ! [[ $cmd_out =~ aws-cli ]]; then
   echo "error: aws cli not installed"
   exit 1
fi

cmd_out=`jq --version`
if ! [[ $cmd_out =~ jq- ]]; then
   echo "error: jq not installed"
   exit 1
fi

total=0
total_unenc=0
pct_unenc=0
sz=0

for i in `aws s3api list-buckets --query "Buckets[].Name" --output text`; do
   total=$((total + 1))

   if [[ "$bash4" -eq "1" ]]; then
      if [[ "$CH_FILLER" -eq  "${blacklist[$i]}" ]]; then
         echo "blacklisted: $i."
         continue
      fi
   fi

   aws s3api get-bucket-encryption --bucket $i >/dev/null 2>&1
   ret=$?
   # sz=`s3cmd du s3://$i | cut -f1 -d ' '` # too slow on large buckets

   cmd="aws cloudwatch get-metric-statistics --namespace AWS/S3 --start-time ${dt}T00:00:00 --end-time ${dt}T23:59:57 --period 86400 --statistics Sum --metric-name BucketSizeBytes --dimensions Name=BucketName,Value=$i Name=StorageType,Value=StandardStorage"
   sz=`$cmd | jq '.Datapoints[] | .Sum' | perl -ne '$n += $_; END { print 0+$n }'`

   if [ "$ret" -ne "0" ]; then
      total_unenc=$((total_unenc + 1))

      if [ "$encrypt" -eq "1" ]; then

         if [[ "$skip_public_buckets" -eq "1" ]]; then
            (aws s3api get-bucket-acl --output text --bucket $i | grep -q http://acs.amazonaws.com/groups/global/AllUsers) && (echo "public: skipping $i"; continue)
         fi

         if [ "$sz" -lt "$max_encrypt" ]; then
            echo "encrypting $i $sz bytes ..."
            # mark bucket as an encrypted bucket
            aws s3api put-bucket-encryption --bucket $i \
               --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
            if [[ "$?" -eq "0" ]]; then
               # copy bucket to itself to encrypt old files with standard SSE AES256 encryption
               aws s3 cp s3://$i/ s3://$i/ --recursive --sse ||
                  echo "error: bucket self-copy failed. You must run it manually: aws s3 cp s3://$i/ s3://$i/ --recursive --sse"
               total_unenc=$((total_unenc - 1))
            fi
         fi
      fi
   fi

   sz=$((sz / MB))

   echo "$i,ret=$ret,$sz MB"

   sleep $delay # rate-limiting to avoid AWS API throttling (optional)
done

if [ "$report" -eq "1" ]; then
   if [ "$total" -ne "0" ]; then
      pct_unenc=$((100 * total_unenc / total))
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

