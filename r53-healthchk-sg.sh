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

while getopts "g:n:p:r:v:h" opt; do
  case $opt in
    g)
      NAME=$OPTARG
      ;;
    n)
      PROFILE=$OPTARG
      ;;
    p)
      PORT=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    v)
      VPCID=$OPTARG
      ;;
    [h?])
      usage
      exit
      ;;
  esac
done

# Test for args
#
if [[ $PROFILE == "" || $REGION == "" || $VPCID == "" ]] ; then
  usage
fi

if [[ $NAME == "" ]]; then
  NAME=route53-healthchk
fi

if [[ $PORT == "" ]]; then
  PORT=80
fi

get_cidr_block () {
  v6=$1
  r53CIDRS=$(curl https://ip-ranges.amazonaws.com/ip-ranges.json 2> /dev/null | grep -B2 ROUTE53_HEALTHCHECKS | grep ip${v6}_prefix | awk -F\" '{print $4}')
  for cidr in ${r53CIDRS}; do
    ip_ranges="${ip_ranges}{\"CidrIp${v6}\": \"${cidr}\"},"
    # echo -n "."
  done
  # Remove last character
  ip_ranges="${ip_ranges%?}"
  echo "\"Ip${v6}Ranges\": [${ip_ranges}]"
}

get_ip_permissions () {
  protocol="tcp"
  port=$1
  echo "[{\"IpProtocol\": \"${protocol}\", \"FromPort\": ${port}, \"ToPort\": ${port}, $(get_cidr_block ''), $(get_cidr_block 'v6')}]"
}

# Our variables
#
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

# Test for valid VPC-Id
#
aws ec2 describe-vpcs --vpc-ids $VPCID --profile $PROFILE --region $REGION > /dev/null 2>&1
check "$VPCID in region $REGION"

# Check for an existing security-group
#
SGId=`aws ec2 describe-security-groups --filters Name=group-name,Values=$NAME --profile $PROFILE --region $REGION --query SecurityGroups[].GroupId | grep sg-`

if [[ $SGId != "" ]]; then
  SGId="$(echo -e $SGId | tr -d '[:space:]' | tr -d '"')"
  echo " $SGId already exists, using."
else
  # Create our security group and record the Id
  #
  echo -n "Creating R53 health check security group "

  aws ec2 create-security-group --group-name $NAME --description $DESC --vpc-id $VPCID --profile $PROFILE --region $REGION --output json > /tmp/sg-id.$$
  SGId=`cat /tmp/sg-id.$$ | grep GroupId | awk -F\" '{print $4}'`
fi

# Populate the security group
#
echo "$(get_ip_permissions $PORT)" > /tmp/ippermissions.$$
populated=`aws ec2 authorize-security-group-ingress --group-id $SGId --profile $PROFILE --region $REGION --ip-permissions file:///tmp/ippermissions.$$`
echo -n "."

# Tag it
#
aws ec2 create-tags --resources $SGId --tags Key=Name,Value=$NAME --profile $PROFILE --region $REGION
# echo ""

echo -n " done!"
echo ""
echo "Security group Id: $SGId"

# Clean up
#
rm -f /tmp/sg-id.$$
rm -f /tmp/ippermissions.$$

exit 0