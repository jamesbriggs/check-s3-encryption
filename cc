cmd_out=`aws --version`
if ! [[ $cmd_out =~ aws-cli ]]; then
   echo "error: aws cli not installed"
   exit 1
fi
