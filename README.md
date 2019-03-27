# check-s3-encryption

**Description**

Check for AWS S3 buckets that are not encrypted and print a report in CSV format and exit with status.

**Usage**

CLI:
```
$ check_s3_encryption.sh

test,ret=255

total buckets=10
total unencrypted buckets=1
percent unencrypted=10%

echo $?
1
```

daily crontab entry:
```
1 1 * * * check_s3_encryption.sh
```

**Requirements**

* AWS CLI tools must be installed and reachable via $PATH
* ~/.aws must be configured with config and credentials files
* tested on Linux and Mac OS X

**License**

MIT License

