## Scenario: Enable Internet Access for a Private EC2 Instance Using a NAT Instance

The Nautilus DevOps team is tasked with enabling internet access for an EC2 instance running in a private subnet. This instance needs to upload a test file to an S3 bucket, but the upload will only succeed once the instance can reach the internet. To minimize costs, the team has decided to use a **NAT Instance** instead of a NAT Gateway.

### Existing Environment

The following components already exist:

1. A VPC named **reach-devops-priv-vpc** (`10.0.0.0/16`) with a private subnet named **reach-devops-priv-subnet** (`10.0.1.0/24` in `ca-central-1a`).
2. An Internet Gateway named **reach-devops-igw** is attached to the VPC but is not associated with any route table.
3. An EC2 instance named **reach-devops-priv-ec2** is running in the private subnet.
4. The EC2 instance is configured with a cron job that uploads a test file to the S3 bucket **reach-devops-nat-15195** every 30 seconds. The upload will only succeed once internet access is established.

### Your Task

1. **Create a public subnet** named **reach-devops-pub-subnet** in the existing VPC. Associate it with a route table that routes internet traffic (`0.0.0.0/0`) through the existing Internet Gateway.

2. **Launch a NAT Instance** in the public subnet using an **Amazon Linux 2** AMI and name it **reach-devops-nat-instance**.
   - Use a **custom security group** that allows appropriate traffic.
   - Ensure the instance is properly configured to act as a NAT instance (hint: consider what EC2 attribute must be changed, and what OS-level configuration is needed to forward traffic).

3. **Update the private subnet's routing** so that internet-bound traffic from **reach-devops-priv-ec2** flows through the NAT instance.

4. **Verify** that the file `reach-devops-test.txt` appears in the S3 bucket `reach-devops-nat-15195`. This confirms that the private EC2 instance has internet access via the NAT instance.

### Success Criteria

```
aws s3 ls s3://reach-devops-nat-15195/
```

Should return:

```
<timestamp> <size> reach-devops-test.txt
```

### Notes

- All resources should be created in the **ca-central-1** region.
- Use the `reach-devops-` naming prefix for all new resources.
- The cron job runs every 30 seconds — allow up to 1 minute after completing your configuration before checking the bucket.
