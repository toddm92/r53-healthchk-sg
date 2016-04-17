#!/bin/bash
#
# Build a Route 53 Health Check security group containing AWS health check CIDRs
# Requires:
#  * the aws-cli
#  * a valid profile in ~/.aws/config or ${AWS_CONFIG_FILE}

# Usage statement
#
usage ()
{
  echo " Build a Route 53 Health Check security group in your VPC."
  echo " >> Usage: $0 -n <profile_name> -r <region> [ -p <port> ]"
  echo " Note: default_port=80"
  exit 1
}

check ()
{
  if [ $? -ne 0 ]; then
    echo " Error: Couldn't find $1. Please check."
    exit 1
  fi
}

while getopts "n:p:r:h" opt; do
  case $opt in
    n)
      PROFILE=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    [h?])
      usage
      exit
      ;;
  esac
done

# Test for args
#
if [[ $PROFILE == "" || $REGION == ""  ]] ; then
  usage
fi

if [[ $PORT == "" ]]; then
  PORT=80
fi

# Our variables
#
NAME=route53-healthchk
DESC=Route-53-health-check-security-group
NUMBER='^[0-9]+$'

# Test for the port number
#
if ! [[ $PORT =~ $NUMBER ]]; then
  echo " Error: Invalid port number."
  exit 1
fi

# Test for the aws-cli
#
which aws > /dev/null 2>&1
check "the aws-cli commands"

# Test the profile
#
aws ec2 describe-regions --profile $PROFILE > /dev/null 2>&1
check "profile $PROFILE"

# Test the region
#
aws ec2 describe-regions --region-names $REGION --profile $PROFILE > /dev/null 2>&1
check "the region $REGION"

# Check for an existing security-group
#
SG=`aws ec2 describe-security-groups --filters Name=description,Values=$DESC --profile $PROFILE --region $REGION --query SecurityGroups[].GroupId | grep sg-`

if [[ $SG != "" ]]; then
  echo " Error: $SG already exists."
  exit 1
fi

# Get the VPC-Id
#
echo -n "Enter your VPC-Id: "
 read VPCId

# Test for valid VPC-Id
#
aws ec2 describe-vpcs --vpc-ids $VPCId --profile $PROFILE --region $REGION > /dev/null 2>&1
check "$VPCId in region $REGION"

# Grab the AWS health check IP CIDRs
#
R53CIDRS=`curl https://ip-ranges.amazonaws.com/ip-ranges.json 2> /dev/null | grep -B2 ROUTE53_HEALTHCHECKS | grep prefix | awk -F\" '{print $4}'`

# Create our security group and record the Id
#
echo -n "Creating R53 health check security group "

aws ec2 create-security-group --group-name $NAME --description $DESC --vpc-id $VPCId --profile $PROFILE --region $REGION --output json > /tmp/sg-id.$$
SGId=`cat /tmp/sg-id.$$ | grep GroupId | awk -F\" '{print $4}'`

# Populate the security group
#
for cidr in ${R53CIDRS}; do
  aws ec2 authorize-security-group-ingress --group-id $SGId --protocol tcp --port $PORT --cidr $cidr --profile $PROFILE --region $REGION
  echo -n "."
done

# Tag it
#
aws ec2 create-tags --resources $SGId --tags Key=Name,Value=$NAME --profile $PROFILE --region $REGION

echo -n " done!"
echo ""
echo "Security group Id: $SGId"

# Clean up
#
rm -f /tmp/sg-id.$$

exit 0