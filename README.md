### Route 53 HealthCheck Security Group

This BASH script creates a Route 53 healthcheck VPC security group.  It grabs a list of AWS CIDRs used to perform health checks
on your services (ELBs, EC2 instances, etc.) and builds a security group that only permits these CIDRs.  The allowed port is
defined using the PORT variable.

**Requirements:**

* The awscli  `sudo pip install awscli`
* A valid profile in `~/.aws/config` or `${AWS_CONFIG_FILE}` with the appropriate API keys
* Your VPC-Id.

**Usage:**

```
r53-healthchk-sg.sh -n <profile_name> -r <region> [ -p <port> ]
```

**Output:**

```
./r53-healthchk-sg.sh -n eng -r us-east-1 -p 5300

Enter your VPC-Id: vpc-45338a20
Creating R53 health check security group ................ done!
Security group Id: sg-60938505
```

The Route 53 Security Group

```
aws ec2 describe-security-groups --group-ids sg-60938505 --profile eng
{
    "SecurityGroups": [
        {
            "GroupId": "sg-60938505",
            "Description": "Route-53-health-check-security-group",
            "GroupName": "route53-healthchk",
            "IpPermissions": [
                {
                    "IpProtocol": "tcp",
                    "ToPort": 5300,
                    "FromPort": 5300,
                    "IpRanges": [
                        {
                            "CidrIp": "54.183.255.128/26"
                        },
                        {
                            "CidrIp": "54.228.16.0/26"
                        },
                        {
                            "CidrIp": "54.232.40.64/26"
                        },
                        {
                            "CidrIp": "54.241.32.64/26"
                        },
                        {
                            "CidrIp": "54.243.31.192/26"
                        },
                        {
                            "CidrIp": "54.244.52.192/26"
                        },
                        {
                            "CidrIp": "54.245.168.0/26"
                        },
                        {
                            "CidrIp": "54.248.220.0/26"
                        },
                        {
                            "CidrIp": "54.250.253.192/26"
                        },
                        {
                            "CidrIp": "54.251.31.128/26"
                        },
                        {
                            "CidrIp": "54.252.79.128/26"
                        },
                        {
                            "CidrIp": "54.252.254.192/26"
                        },
                        {
                            "CidrIp": "54.255.254.192/26"
                        },
                        {
                            "CidrIp": "107.23.255.0/26"
                        },
                        {
                            "CidrIp": "176.34.159.192/26"
                        },
                        {
                            "CidrIp": "177.71.207.128/26"
                        }
                    ],
                    "UserIdGroupPairs": []
                }
            ],
            "VpcId": "vpc-45338a20",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "UserIdGroupPairs": []
                }
            ],
            "OwnerId": "XXXXXXXX5893",
            "Tags": [
                {
                    "Value": "route53-healthchk",
                    "Key": "Name"
                }
            ]
        }
    ]
}
```

**To Do:**

- [x] Add a check for an existing security group
- [x] Add multi-region support!
