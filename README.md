
# Secure and monitor a private web server - ALB + SSM + CloudWatch
**Status :** 🟠 Work in progress
<br/>
<br/>
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<img width="107" height="60" alt="Amazon-Web-Services-AWS-Logo" src="https://github.com/user-attachments/assets/f7829385-3361-48fc-8099-849da5534de5" />
&emsp;<img width="75" height="86" alt="Terraform-Logo" src="https://github.com/user-attachments/assets/b037706b-3866-4376-9b2d-55c91b6dafc0" />


## Summary 
- [Introduction](#1-introduction)
- [Design Decisions](#2-design-decisions)
- [Architecture Overview](#3-architecture-overview)
- [Deployment](#4-deployment)
- [Pricing](#5-pricing)
- [Improvements & Next Steps](#6-improvements--next-steps)
- [References](#7-references)
<br/>
<br/>
<br/>

## 1. Introduction 
<a name="#1-introduction"></a>     
&emsp;&emsp;This project showcases a scalable and monitored architecture on AWS.         
It deploys a web application behind an Application Load Balancer (ALB) in a private VPC, using an Auto Scaling Group of EC2 instances.   
Maintenance and connectivity are handled via AWS Systems Manager (SSM), without direct SSH access, and monitoring is centralized with CloudWatch (metrics and alerts).
<br/>
<br/>

## 2. Design Decisions   
<a name="#2-design-decisions"></a>

<br/>

| Components                                             | Justification                 |
|--------------------------------------------------------|-------------------------------|
| **Terraform**                                          | Reproducibility, version control, automated deployments, costs optimization | 
| **2 private subnets for the Auto Scaling Group**       | High Availability and resilience in case of an AZ failure                 | 
| **VPC endpoint over NAT Gateway**                      | Costs saving, sufficient for maintenance when internet access is not required for workloads               | 
| **Session Manager over SSH key**                       | Stengthen security by closing port 22, simplify access management              |               
| **Single CloudWatch Alarm**                            | Demonstration simplicity             |

<br/>
<br/>
<br/>

## 3. Architecture Overview
<a name="#3-architecture-overview"></a>     
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/c53acb03-e611-4e65-b860-e8c4baada7e8" />

<br/>
<br/>     
   
| Components         | AWS Service                   | Role                           | 
|-------------------|-------------------------------|--------------------------------|
| **Network**       | VPC, Availability Zones, subnets, Internet GateWay, VPC endpoint | Segmentation, High Availability, Internet access     |
| **Compute**       | EC2 instances, Auto Scaling Group                 | Workload execution             | 
| **Security**      | Security groups, SSM Manager               | Access control and protection  | 
| **Observability** | Cloudwatch, SNS               | Monitoring and alerting        |                       
| **Managment**     | SSM Manager, S3               | Web server maintenance         |

<br/>
<br/>
<br/>

## 4. Deployment
<a name="#4-deployment"></a>

<br/>

### <ins>Prerequisites:</ins>
- Active AWS account.   
- AWS CLI configured.   
- Terraform installed.   

<br/>

### Step 1 - Clone this repo  

```bash
git clone https://github.com/MarineFurlan/AWS_Scalable_Infra_ALB_SSM_Maintenance_CloudWatch.git
cd AWS_Scalable_Infra_ALB_SSM_Maintenance_CloudWatch
```
<br/>

### Step 2 - Initialize the infrastructure
```bash
terraform init
terraform plan
terraform apply
```  

### Step 3 - Confirm the subscription to security alerts in your email inbox. 
    
![Email_notif](https://github.com/user-attachments/assets/df101df1-d6b3-4f3d-9888-5a7e0b9f3934)

<!--- ### Step 4 - Deployment validation
```bash
# Commande pour vérifier que tout fonctionne
aws cloudformation describe-stacks --stack-name $PROJECT_NAME --query "Stacks[0].StackStatus"
# Résultat attendu : "CREATE_COMPLETE"
```
-->

## 5. Results

&emsp;&emsp;After verifying in the AWS console that the created resources match the intended infrastructure, the following tests can be performed:  
<br/>

### _Application Access via ALB_

- Copy the ALB DNS address from the outputs and access it in a browser.  

![dns_output](https://github.com/user-attachments/assets/905eece7-aba0-4811-a524-35eb39e3ff18)
  
- If successful, the page will display "Hello from {current-instance}". Refreshing multiple times will show the load balancing across instances.

<img width="776" height="82" alt="First_instance_in_server" src="https://github.com/user-attachments/assets/b6ce9de0-f6ba-44b8-aec8-e854bf093089" />
<img width="776" height="82" alt="Second_instance_in_server" src="https://github.com/user-attachments/assets/4bc10bc6-3aed-4ce4-b3cb-2cf701de04a3" />

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

- Stop one instance to simulate an AZ issue. The target group will immediately mark it as unhealthy, and traffic will shift to the remaining instance.
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




11. If needed, destroy the infrastructure with *terraform destroy*.
<br/>
<br/>

## 5. Pricing
<a name="#5-pricing"></a>
&emsp;&emsp;The infrastructure was designed with a cost-efficiency approach, balancing AWS best practices with budget optimization.  
The estimate below is based on the [AWS Pricing Calculator](https://calculator.aws).  

| Service                      | Selected Option                   | Estimated Monthly*  | Justification |
|------------------------------|----------------------------------|---------------------|---------------|
| **EC2 (Auto Scaling Group)** | 2 t2.micro instances with EC2 Instance Savings Plan (1 year) | ~13.43 USD           | Stable instance family. Single region. ~2.05 USD/month cheaper than Compute Savings Plan. |
| **Application Load Balancer**| 1 active ALB                      | 19.32 USD           | Required for traffic routing across multiple instances. |
| **VPC Endpoint (S3)**        | 1 Gateway Endpoint                | 0 USD               | Free to use, unlike a NAT Gateway. |
| **VPC Endpoint (SSM)**       | 3 Interface Endpoints (ssm, ec2messages, ssmmessages) x 2 AZs | 48.18 USD           | More secure and ~24.82 USD/month cheaper than a NAT Gateway. |
| **CloudWatch**               | 1 alarm + basic metrics           | 0 USD               | Free within Free Tier (10 metrics + 10 alarms/month + 5GB logs). Current setup stays within Free Tier. |
| **SSM Session Manager**      | Included in Free Tier             | 0 USD               | No additional cost for basic access without CloudWatch logging. |
| **TOTAL**                    |                                  | **67.8 USD**        |

\* Costs estimated for region "eu-west-3". Includes fixed service costs only, not traffic-related costs.  

<br/>  

### <ins>Key Budget Decisions</ins>

| Service                      | Alternative Option                | Estimated Monthly*  |
|------------------------------|----------------------------------|---------------------|
| _NAT Gateway_                | _1 NAT x 2 AZs_                   | _73 USD_           |

- **VPC endpoints vs NAT Gateway**:  
24.82 USD/month fixed cost savings.  

- **EC2 Instance Savings Plans vs Compute Savings Plan**:  
Since the scaling is horizontal, the instance type is not expected to change, and the VPC is confined to one region. The "EC2 Instance Savings Plan" is more suitable, offering discounts for consistent instance family and region.  
For a 1-year commitment:  
  - EC2 Instance Savings Plan = 6.72 USD/month/instance  
  - Compute Savings Plan = 7.74 USD/month/instance  
Savings = 1.02 USD/month/instance, i.e., ~2.05 USD/month for this infrastructure.  
<br/> 
<br/>
<br/>

## 6. Improvements & Next Steps
<a name="#6-improvements--next-steps"></a>
Potential enhancements to the infrastructure include:  
- **Integrating a WAF (Web Application Firewall)** to strengthen protection against attacks and extend monitoring scope.  

<br/>

- Configuring the ALB with **HTTPS and an ACM certificate** and **Automating HTTP-to-HTTPS redirection** to encrypt traffic and improve security.  

<br/>

- **Extending monitoring** (application logs, additional metrics, custom dashboards) to better anticipate issues and track application usage. 
<br/>
<br/>
<br/>

## 7. References
<a name="#7-references"></a>   
:link:[Application Load Balancer – AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  
:link:[Auto Scaling Groups – AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)  
:link:[PrivateLinks – AWS Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)  
:link:[AWS Systems Manager (SSM) – AWS Docs](https://docs.aws.amazon.com/systems-manager/)  
:link:[Amazon CloudWatch Monitoring – AWS Docs](https://docs.aws.amazon.com/cloudwatch/)  
:link:[AWS Pricing Calculator](https://calculator.aws/#/)  
:link:[AWS Free Tier](https://aws.amazon.com/free) 
