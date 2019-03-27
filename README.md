# check-s3-encryption

**Description**

Check for AWS S3 buckets that are not encrypted and print a report in CSV format and exit with status.

**Usage**

CLI:

$ check-s3-encryption.sh

daily crontab entry:

1 1 * * * check-s3-encryption.sh

**Requirements**

* AWS CLI tools must be installed and reachable via $PATH
* ~/.aws must be configured with config and credentials files
* tested on Linux and Mac OS X

**License**

MIT License

