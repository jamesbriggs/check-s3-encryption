# check-s3-encryption

**Description**

Check for AWS S3 buckets that are not encrypted and optionally encrypt them with SSE AES256, print a report in CSV format and exit with status.

For faster results with large buckets (> 10 GB) or millions of files, run from linux `screen` an an instance in the same AWS AZ as your S3 buckets.

**Usage**

CLI:
```
$ check_s3_encryption.sh

test,ret=255,0

total buckets=10
total unencrypted buckets=1
percent unencrypted=10%
total blacklisted buckets=0

echo $?
1
```

daily crontab entry:
```
1 1 * * * /path/check_s3_encryption.sh
```

**Requirements**

* current AWS CLI tools must be installed and reachable via $PATH
* ~/.aws must be configured with config and credentials files
* jq is needed to calculate bucket sizes
* tested on Linux and Mac OS X

**Warning**

"Copying the object over itself removes settings for storage-class and website-redirect-location. To maintain these settings in the new object, be sure to explicitly specify storage-class or website-redirect-location values in the copy request."

Use at your own risk - if you enable encrypt=1, there is considerable risk of dropping redirects and permissions.

**License**

MIT License

