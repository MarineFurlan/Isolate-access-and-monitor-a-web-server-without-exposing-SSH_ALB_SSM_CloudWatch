# Isolate, access and monitor a web server without exposing SSH - ALB + SSM + CloudWatch

**Status :** 🟢 Done
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
- [Infrastructure cleaning](#6-infrastructure-cleaning)
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

<br/>

```terraform
git clone https://github.com/MarineFurlan/Isolate-access-and-monitor-a-web-server-without-exposing-SSH_ALB_SSM_CloudWatch.git
cd Isolate-access-and-monitor-a-web-server-without-exposing-SSH_ALB-SSM-CloudWatch
```
</details>

<br/>

<details>
<summary>Step 2 - Review and complete variables.tf file</summary>  

<br/>

Change the default value of the email_address variable, it must be the email address that will receive alerts.
```terraform
variable "email_address" {
  type = string
  default = "[your_email]"
}
```  
</details>

<br/>

<details>
<summary>Step 3 - Initialize the infrastructure</summary>  

<br/>
  
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


Step 4 - Confirm the subscription to security alerts in your email inbox.



<br/>

<details>
<summary>Step 5 - Deployment validation</summary>

<br/>

A serie of tests will now be executed to review the infrastructure and its integrity.

<br/>

<img width="2101" height="1204" alt="AWS_Scalable_Infra_Tests" src="https://github.com/user-attachments/assets/7e5daa7e-df15-43b2-bce4-e8bf01a23af7" />

<br/>
<br/>

```bash
# Run the validation tests
bash tests.sh
```
```bash
# Expected results
══════════════════════════════════════════
  0 / INITIALIZATION
══════════════════════════════════════════
  → Loading variables from Terraform outputs...
  
[...]

══════════════════════════════════════════
  TEST SUMMARY
══════════════════════════════════════════
  Tests run    : 8
  Passed       : 8                                                                                                                                                                                                                  
  Failed       : 0                                                                                                                                                                                                                  

  ✔ All tests passed — lab validated successfully.

  ℹ  Check your inbox for the SNS alert email triggered by the 4XX simulation.
  ℹ  Run terraform destroy when done to avoid unnecessary costs.                                                                                                                                                                    

```
</details>

<br/>
<br/>
<br/>

## 5. Results
<a name="#5-results"></a>

Infrastructure overview :

<img width="1569" height="450" alt="Infra_overview" src="https://github.com/user-attachments/assets/fbd32ce5-41f2-4109-a3c8-515801935cfa" />

<br/>
<br/>
<br/>

## 6. Infrastructure cleaning
<a name="#6-infrastructure-cleaning"></a>

To avoid unexpected fees, destroying the infrastructure after the completion of this lab is good practice.

```terraform
terraform plan -destroy
terraform destroy -auto-approve
```  

<br/>
<br/>
<br/>

## 7. Pricing

<a name="#7-pricing"></a>

<details>
<summary>Monthly estimation</summary>

<br/>  
  
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
| **SNS**                       | < 1000 emails                                                 | 0 USD              | Current setup stays within Free Tier.                                                                  |
| **SSM Session Manager**       | Included in Free Tier                                         | 0 USD              | No additional cost for basic access without CloudWatch logging.                                        |
| **TOTAL**                     |                                                               | **67.8 USD**       |

\* Costs estimated for region "eu-west-3". Includes fixed service costs only, not traffic-related costs. Calculated in 2025.
</details>
   

<details>
<summary>Key Budget Decisions</summary>

<br/>  

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
</details>

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

<br/>
<br/>
<br/>

## Author
**Furlan Marine - Certified AWS Solutions Architect - Associate** \
📌https://www.linkedin.com/in/marinefurlan/ \
🎓https://www.credly.com/badges/06426b31-106e-4251-b866-6da8f4200e68/linked_in?t=t7j3hl
