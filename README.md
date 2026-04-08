# Isolate, access and monitor a web server without exposing SSH - ALB + SSM + CloudWatch

**Status :** 🟠 Work in progress
<br/>
<br/>
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<img width="107" height="60" alt="Amazon-Web-Services-AWS-Logo" src="https://github.com/user-attachments/assets/f7829385-3361-48fc-8099-849da5534de5" />
&emsp;<img width="75" height="86" alt="Terraform-Logo" src="https://github.com/user-attachments/assets/b037706b-3866-4376-9b2d-55c91b6dafc0" />

## Table of contents

- [Introduction](#1-introduction)
- [Design Decisions](#2-design-decisions)
- [Architecture Overview](#3-architecture-overview)
- [Deployment](#4-deployment)
- [Results](#5-results)
- [Infrastructure cleaning](#6-infra-cleaning)
- [Pricing](#7-pricing)
- [Improvements & Next Steps](#8-improvements--next-steps)
- [References](#9-references)
  <br/>
  <br/>
  <br/>

## 1. Introduction

<a name="#1-introduction"></a>     
&emsp;&emsp;This lab walks through deploying EC2 instances in private subnets behind an Application Load Balancer,
eliminating any direct exposure to the public internet.\
Access to the instances is exclusively managed through Systems Manager (SSM), removing the need for SSH. CloudWatch is
used to monitor incoming traffic and trigger alerts on abnormal traffic such as HTTP 4XX errors.
<br/>
<br/>

## 2. Design Decisions

<a name="#2-design-decisions"></a>

<br/>

| Components                                       | Justification                                                                               |
|--------------------------------------------------|---------------------------------------------------------------------------------------------|
| **Terraform**                                    | Reproducibility, version control, automated deployments, costs optimization                 | 
| **2 private subnets for the Auto Scaling Group** | High Availability and resilience in case of an AZ failure                                   | 
| **VPC endpoint over NAT Gateway**                | Costs saving, sufficient for maintenance when internet access is not required for workloads | 
| **Session Manager over SSH key**                 | Stengthen security by closing port 22, simplify access management                           |               
| **Single CloudWatch Alarm**                      | Demonstration simplicity                                                                    |

<br/>
<br/>
<br/>

## 3. Architecture Overview

<a name="#3-architecture-overview"></a>     
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/c53acb03-e611-4e65-b860-e8c4baada7e8" />

<br/>
<br/>     

| Components        | AWS Service                                                      | Role                                             | 
|-------------------|------------------------------------------------------------------|--------------------------------------------------|
| **Network**       | VPC, Availability Zones, subnets, Internet GateWay, VPC endpoint | Segmentation, High Availability, Internet access |
| **Compute**       | EC2 instances, Auto Scaling Group                                | Workload execution                               | 
| **Security**      | Security groups, SSM Manager                                     | Access control and protection                    | 
| **Observability** | Cloudwatch, SNS                                                  | Monitoring and alerting                          |                       
| **Managment**     | SSM Manager, S3                                                  | Web server maintenance                           |

<br/>
<br/>
<br/>

## 4. Deployment

<a name="#4-deployment"></a>

<br/>

<details>
<summary>Prerequisites</summary>

- Active AWS account
- Bash terminal
- AWS CLI configured
- Session Manager Plugin installed
- Terraform installed
</details>

<br/>

<details>
<summary>Step 1 - Clone this repo</summary> 

```terraform
git clone https://github.com/MarineFurlan/AWS_Scalable_Infra_ALB_SSM_Maintenance_CloudWatch.git
cd AWS_Scalable_Infra_ALB_SSM_Maintenance_CloudWatch
```
</details>

<br/>

<details>
<summary>Step 2 - Initialize the infrastructure</summary>  
  
```terraform
terraform init
terraform plan
terraform apply
```  
```terraform
# Expected result in CLI

Apply complete! Resources: 31 added, 0 changed, 0 destroyed.                                                                                                                                                                        

Outputs:                                                                                                                                                                                                                            

alb_arn_suffix = "app/webApp-alb/XXXXXXXXX"
alb_dns = "webApp-alb-XXXXXXXXX.eu-west-3.elb.amazonaws.com"
asg_name = "webApp-ec2-sg"
cloudwatch_alarm_name = "webApp-ALB-4xx-alarm"
ec2_security_group_id = "sg-XXXXXXXXX"
sns_topic_arn = "arn:aws:sns:eu-west-3:XXXXXXXXX:vpc_alerts_webApp"
target_group_arn = "arn:aws:elasticloadbalancing:eu-west-3:XXXXXXXXX:targetgroup/webApp-tg/XXXXXXXXX"
```
</details>

<br/>

<details>
<summary>Step 3 - Confirm the subscription to security alerts in your email inbox.</summary>

```bash
# Store the SNS topic arn in a variable
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)

# Is our email subscribed to the SNS topic ?
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN \
  --query 'Subscriptions[0].SubscriptionArn' --output text
```
```bash
# Expected Result
$SNS_TOPIC_ARN:XXXXXXXXX # If subscribed
PendingConfirmation # If not subscribed
```
</details>

<br/>

<details>
<summary>Step 4 - Deployment validation</summary>

#### _ALB access_
```bash
# Store ALB dns in a variable
ALB_DNS=$(terraform output -raw alb_dns)

# Display alb address
echo "ALB endpoint : http://$ALB_DNS"
```
```bash
#Expected results
ALB endpoint : http://webApp-alb-XXXXXXXXX.eu-west-3.elb.amazonaws.com
```
```bash
# Can we access the webserver through the ALB ?
curl -s http://$ALB_DNS
```
```bash
#Expected results
<h1>Hello from ip-10-0-101-152.eu-west-3.compute.internal</h1>
```
<br/>

#### _Closed SSH port_
```bash
# Store Security group ID in a variable
SG_ID=$(terraform output -raw ec2_security_group_id)

# Is the SSH port on instances closed ?
aws ec2 describe-security-groups --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
  --output json
  ```
```bash
#Expected results
[] # If closed
# If open
```
```bash
# Confirmer que l'unique source de trafic entrant autorisée est l'ALB
aws ec2 describe-security-groups --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions[*].{Port:FromPort,Source:UserIdGroupPairs[0].GroupId}' \
  --output table
 ```
```bash
#Expected results
----------------------------------                                                                                                                                                                                                 
|     DescribeSecurityGroups     |
+------+-------------------------+
| Port |         Source          |
+------+-------------------------+
|  80  |        [ALB-sg]         |
+------+-------------------------+
```
<br/>

#### _SSM instance connection_
```bash
# List all registered instances in the SSM Fleet Manager
aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].{ID:InstanceId,Status:PingStatus,Platform:PlatformName}' \
  --output table
```
```bash
#Expected Result
---------------------------------------------------                                                                                                                                                                                
|           DescribeInstanceInformation           |
+----------------------+----------------+---------+
|          ID          |   Platform     | Status  |
+----------------------+----------------+---------+
|  i-XXXXXXXXX         |  Amazon Linux  |  Online |
|  i-XXXXXXXXX         |  Amazon Linux  |  Online |
+----------------------+----------------+---------+
```
```bash
# Can we connect to the first instance with SSM Connect ?
INSTANCE_ID=$(aws ssm describe-instance-information \
  --query 'InstanceInformationList[0].InstanceId' --output text)
  
aws ssm start-session --target $INSTANCE_ID
```
```bash
#Expected Result
Starting session with SessionId: marine-jpblbg89g464jk82rx4riv9dbq
sh-5.2$
```
<br/>

#### _New instance created in case of AZ failure_
```bash
# Is there new instances created when an AZs is down ?
```
```bash
#Expected Result
...
```
<br/>

#### _Alarm triggered_
```bash
# Is the Cloudwatch alarm triggered when the webserver is under attack ?
```
```bash
#Expected Result
...
```
<br/>

#### _Email sent_
```bash
# Is the alarm email sent when the alarm is ON ?
```
```bash
#Expected Result
...
```
</details>

<br/>

## 5. Results
<a name="#5-results"></a>

Infrastructure overview :

<br/>

<img width="1569" height="450" alt="Infra_overview" src="https://github.com/user-attachments/assets/fbd32ce5-41f2-4109-a3c8-515801935cfa" />

<!--
- Screenshots below show how to identify which instance has which IP:
  <img width="776" height="82" alt="First_instance_ip" src="https://github.com/user-attachments/assets/5316ee90-05e6-409e-b3bf-d8b3353c7116" />
  <img width="776" height="82" alt="Second_instance_ip" src="https://github.com/user-attachments/assets/0438c297-6f23-4363-be60-181b15186cf0" />

- In the AWS console, the target group will show healthy instances across different AZs:
  <img width="832" height="791" alt="target_group" src="https://github.com/user-attachments/assets/4418ea7a-f2bb-4194-a283-3faef77cdd63" />

<br/>

<br/>  

<br/>

### _Maintenance Connection via SSM_

- Check that SSM Connect access is available.
  <img width="1776" height="498" alt="ssm_connect" src="https://github.com/user-attachments/assets/9100b977-c117-46f3-a782-3a042fd2b21f" />

<br/>

<br/>  

<br/>

### _Resiliency in case of failure_

- Stop one instance to simulate an AZ issue. The target group will immediately mark it as unhealthy, and traffic will
  shift to the remaining instance.
  <img width="776" height="82" alt="Stopped_instance" src="https://github.com/user-attachments/assets/6ddd16cb-dac6-415f-9133-3e40adca58ed" />


- After some time, the unhealthy instance is drained and replaced by a new one.
  <img width="776" height="82" alt="Draining_instance" src="https://github.com/user-attachments/assets/4d3f13a2-279f-4571-84b7-c09ac1662cf3" />
  <img width="776" height="82" alt="New_instance_booted" src="https://github.com/user-attachments/assets/9bf8858f-2737-42ae-8ac5-684167405cf2" />


- Traffic can now be routed to the new instance.
  <img width="776" height="82" alt="new_instance_ip" src="https://github.com/user-attachments/assets/c9bba3d2-5dd7-48fc-9e42-2597cae48f04" />
  <img width="776" height="82" alt="Third_instance_in_server" src="https://github.com/user-attachments/assets/b5d1790e-8665-441a-b0ef-428eb9b632af" />

<br/>

<br/>  

### _Triggering the Alarm on 4XX Errors_

- In Amazon SNS > Topics > vpc_alerts_webApp: verify the email subscription to receive alerts.

<img width="776" height="82" alt="Email_confirmed" src="https://github.com/user-attachments/assets/e4dafef2-5bf2-423c-a8e9-51cef8ceb3cf" />

- Simulate 4xx errors with, for instance, this PowerShell snippet:

```PowerShell
1..12 | ForEach-Object { try { Invoke-WebRequest "http://{alb_dns}/chemin-invalide$($_)?r=$(Get-Random)" -Method GET -ErrorAction Stop -TimeoutSec 5 | Out-Null; "200" } catch { if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "ERR" } } }
```

After 4–5 minutes, the email alert is received:

![email_alarm](https://github.com/user-attachments/assets/95abb978-4a51-48a7-aa14-5ed9e17a5ad8)
-->

## 6. Infrastructure cleaning
<a name="#6-infra-cleaning"></a>
```terraform
terraform plan -destroy
terraform destroy -auto-approve
```  

<br/>

## 7. Pricing

<a name="#7-pricing"></a>
&emsp;&emsp;The infrastructure was designed with a cost-efficiency approach, balancing AWS best practices with budget
optimization.  
The estimate below is based on the [AWS Pricing Calculator](https://calculator.aws).

| Service                       | Selected Option                                               | Estimated Monthly* | Justification                                                                                          |
|-------------------------------|---------------------------------------------------------------|--------------------|--------------------------------------------------------------------------------------------------------|
| **EC2 (Auto Scaling Group)**  | 2 t2.micro instances with EC2 Instance Savings Plan (1 year)  | ~13.43 USD         | Stable instance family. Single region. ~2.05 USD/month cheaper than Compute Savings Plan.              |
| **Application Load Balancer** | 1 active ALB                                                  | 19.32 USD          | Required for traffic routing across multiple instances.                                                |
| **VPC Endpoint (S3)**         | 1 Gateway Endpoint                                            | 0 USD              | Free to use, unlike a NAT Gateway.                                                                     |
| **VPC Endpoint (SSM)**        | 3 Interface Endpoints (ssm, ec2messages, ssmmessages) x 2 AZs | 48.18 USD          | More secure and ~24.82 USD/month cheaper than a NAT Gateway.                                           |
| **CloudWatch**                | 1 alarm + basic metrics                                       | 0 USD              | Free within Free Tier (10 metrics + 10 alarms/month + 5GB logs). Current setup stays within Free Tier. |
| **SSM Session Manager**       | Included in Free Tier                                         | 0 USD              | No additional cost for basic access without CloudWatch logging.                                        |
| **TOTAL**                     |                                                               | **67.8 USD**       |

\* Costs estimated for region "eu-west-3". Includes fixed service costs only, not traffic-related costs.

<br/>  

### <ins>Key Budget Decisions</ins>

| Service       | Alternative Option | Estimated Monthly* |
|---------------|--------------------|--------------------|
| _NAT Gateway_ | _1 NAT x 2 AZs_    | _73 USD_           |

- **VPC endpoints vs NAT Gateway**:  
  24.82 USD/month fixed cost savings.

- **EC2 Instance Savings Plans vs Compute Savings Plan**:  
  Since the scaling is horizontal, the instance type is not expected to change, and the VPC is confined to one region.
  The "EC2 Instance Savings Plan" is more suitable, offering discounts for consistent instance family and region.  
  For a 1-year commitment:
    - EC2 Instance Savings Plan = 6.72 USD/month/instance
    - Compute Savings Plan = 7.74 USD/month/instance  
      Savings = 1.02 USD/month/instance, i.e., ~2.05 USD/month for this infrastructure.  
      <br/>
      <br/>
      <br/>

## 8. Improvements & Next Steps

<a name="#8-improvements--next-steps"></a>
Potential enhancements to the infrastructure include:

- **Integrating a WAF (Web Application Firewall)** to strengthen protection against attacks and extend monitoring scope.

<br/>

- Configuring the ALB with **HTTPS and an ACM certificate** and **Automating HTTP-to-HTTPS redirection** to encrypt
  traffic and improve security.

<br/>

- **Extending monitoring** (application logs, additional metrics, custom dashboards) to better anticipate issues and
  track application usage.
  <br/>
  <br/>
  <br/>

## 9. References

<a name="#9-references"></a>   
:link:[Application Load Balancer – AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  
:link:[Auto Scaling Groups – AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)  
:link:[PrivateLinks – AWS Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)  
:link:[AWS Systems Manager (SSM) – AWS Docs](https://docs.aws.amazon.com/systems-manager/)  
:link:[Amazon CloudWatch Monitoring – AWS Docs](https://docs.aws.amazon.com/cloudwatch/)  
:link:[AWS Pricing Calculator](https://calculator.aws/#/)  
:link:[AWS Free Tier](https://aws.amazon.com/free) 
