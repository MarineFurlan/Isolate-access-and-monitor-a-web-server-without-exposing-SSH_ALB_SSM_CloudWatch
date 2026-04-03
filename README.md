
# Secure and monitor a private web server - ALB + SSM + CloudWatch
<br/>
<br/>
&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;&emsp;<img width="107" height="60" alt="Amazon-Web-Services-AWS-Logo" src="https://github.com/user-attachments/assets/f7829385-3361-48fc-8099-849da5534de5" />
&emsp;<img width="75" height="86" alt="Terraform-Logo" src="https://github.com/user-attachments/assets/b037706b-3866-4376-9b2d-55c91b6dafc0" />


## Summary 
- [Introduction](#1-introduction)
- [Design Decisions](#2-design-decisions)
- [Architecture Overview](#3-architecture-overview)
- [Features](#4-features)
- [Deployment Steps](#5-deployment-steps)
- [Pricing](#6-pricing)
- [Improvements & Next Steps](#7-improvements--next-steps)
- [References](#8-references)
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
### <ins>Terraform</ins>
Using IaC ensures reproducibility, version control, and automated deployments. The infrastructure can be deployed or destroyed with a single command, optimizing costs and agility.     

### <ins>2 Private Subnets for the ASG</ins>
This guarantees high availability and resilience in case of an AZ (Availability Zone) failure.  

### <ins>VPC Endpoint S3 instead of a NAT Gateway (cost and limited internet needs)</ins> 
Private instances do not require constant internet access. A free and secure S3 endpoint is sufficient for bootstrap and avoids the high costs of a NAT Gateway.  
  
### <ins>Session Manager to enhance security by keeping SSH closed</ins>
Port 22 remains closed. Access to instances is done through Systems Manager, strengthening security and simplifying access management.
  
### <ins>Single CloudWatch Alarm for simplicity</ins>
One alarm on 4XX errors demonstrates monitoring and notification while keeping complexity and costs low. 
<br/>
<br/>
<br/>

## 3. Architecture Overview
<a name="#3-architecture-overview"></a>     
<img width="2028" height="1049" alt="WebApp_EmailAlarm_SSMConnect drawio(1)" src="https://github.com/user-attachments/assets/c53acb03-e611-4e65-b860-e8c4baada7e8" />

      
### Main Components: 
   
:open_file_folder:[ALB (Application Load Balancer)](./modules/alb/main.tf) : traffic routing
<details>
  
<summary>See ALB code</summary>
  
```terraform
resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  subnets            = var.public_subnets_ids
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]

  tags = { Name = "${var.name}-alb-tg" }
}
```

</details>

<details>
  
<summary>See target group code</summary>

```terraform
resource "aws_lb_target_group" "alb" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    interval            = 10
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
    matcher             = "200-399"
  }

  deregistration_delay = 60
}
```
</details>

<details>
  
<summary>See listener code</summary>

```terraform
resource "aws_lb_listener" "alb" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}
```
 </details> 
 
:open_file_folder:[EC2 Auto Scaling Group](./modules/asg/main.tf): automatically adjusts the number of instances based on load.   
   
:open_file_folder:[Private Subnets](./modules/vpc/main.tf): instances isolated from direct internet traffic.   
   
:open_file_folder:[VPC Endpoints](./modules/vpc_endpoints/main.tf): private connectivity to S3 (bootstrap) and SSM (maintenance).   
> [!NOTE]
> For the reasoning behind using VPC endpoints instead of a NAT Gateway or SSH, see [Design Decisions](#2-design-decisions). 

<details>
  
<summary>See VPC endpoint for s3 code</summary>

```terraform
resource "aws_vpc_endpoint" "s3" {
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  vpc_id            = var.vpc_id

  route_table_ids = var.private_rt_id

  tags = { Name = "${var.name}-s3-endpoint" }
}
```
</details>

<details>
  
<summary>See VPC endpoint for ssm code</summary>

```terraform
resource "aws_vpc_endpoint" "ssm" {
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  vpc_id              = var.vpc_id
  subnet_ids          = var.private_subnets_ids
  security_group_ids = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.name}-ssm-endpoint" }
}
```
</details>

:open_file_folder:[CloudWatch Monitoring](./modules/cloudwatch/main.tf): tracks metrics and configures alarms (4XX errors).
<br/>
<br/>
<br/>

## 4. Features
<a name="#4-features"></a>   

<br/>

- **_Scalability_**: EC2 instances auto scale based on demand.
  
<br/>

- **_High Availability_**: ASG instances are deployed across two private subnets in different AZs, ensuring resilience and service continuity.
  
<br/> 

- **_Security_**: instances in a private network, no SSH exposure, maintenance only via SSM Session Manager through VPC endpoint.
  
<br/>

- **_Monitoring_**: CloudWatch alarm for 4XX errors.

<br/>

- **_Reproducibility and Automation_**: automated and reproducible deployments with Terraform.

<br/>  

- **_Optimization_**: private instances access S3 via VPC endpoint for configuration files at boot, reducing costs.

<br/>
<br/>
<br/>

## 5. Deployment Steps
<a name="#5-deployment-steps"></a>
&emsp;&emsp;The infrastructure is deployed with Terraform, enabling fast, repeatable, automated, and version-controlled deployments.  
Here are the main steps to reproduce the environment:  

### <ins>Prerequisites:</ins>
- Active AWS account.   
- AWS CLI configured.   
- Terraform installed.   
  
### <ins>Deployment Steps:</ins>   

1. Write the [VPC](./modules/vpc/main.tf) with public and private subnets.  
2. Write the [VPC endpoints](./modules/vpc_endpoints/main.tf) for SSM and S3.  
3. Write the [Application Load Balancer (ALB)](./modules/alb/main.tf).  
4. Write the [Auto Scaling Group](./modules/asg/main.tf) of EC2 instances in the private subnets.  

<details>
  
<summary>See asg code</summary>

```terraform
resource "aws_autoscaling_group" "this" {
  name = "${var.name}-asg"

  min_size            = var.min_capacity
  max_size            = var.max_capacity
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnets_ids

  launch_template {
    id      = aws_launch_template.webApp.id
    version = "$Latest"
  }

  target_group_arns = [var.tg_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 30

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-asg"
    propagate_at_launch = true
  }

}
```
</details>

<details>
  
<summary>See launch template code</summary>

```terraform

resource "aws_launch_template" "webApp" {
  name_prefix   = "${var.name}-lt"
  image_id      = var.ami
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd

              INSTANCE_ID = $(curl -s http://169.254.169.254/latest/meta-data/instance-id)


              echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.webApp.id]
  }

  lifecycle {
    create_before_destroy = true
  }
}
```
</details>

5. Write the [CloudWatch Alarm](./modules/cloudwatch/main.tf) on Target_4XXCount.  
<details>
  
<summary>See alarm code</summary>

```terraform
resource "aws_cloudwatch_metric_alarm" "alb_4xx_alarm" {
  alarm_name          = "${var.name}-ALB-4xx-alarm"
  alarm_description   = "Alarm when ALB returns too many 4XX responses"
  metric_name         = "HTTPCode_Target_4XX_Count"
  namespace           = "AWS/ApplicationELB"
  evaluation_periods  = 1
  period              = 60
  statistic           = "Sum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 10
  dimensions = { LoadBalancer = var.alb_arn_suffix }
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```
</details>

6. Run *terraform init* to initialize the modules.
   
7. Run *terraform plan* to review what will be created. Enter the requested email in the console to enable alert notifications.

8. Run *terraform apply* and confirm the email address in the console. The infrastructure is deployed.

9. Confirm the subscription to security alerts in your email inbox. 
    
![Email_notif](https://github.com/user-attachments/assets/df101df1-d6b3-4f3d-9888-5a7e0b9f3934)
   
### <ins>Tests</ins>

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

## 6. Pricing
<a name="#6-pricing"></a>
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

## 7. Improvements & Next Steps
<a name="#7-improvements--next-steps"></a>
Potential enhancements to the infrastructure include:  
- **Integrating a WAF (Web Application Firewall)** to strengthen protection against attacks and extend monitoring scope.  

<br/>

- Configuring the ALB with **HTTPS and an ACM certificate** and **Automating HTTP-to-HTTPS redirection** to encrypt traffic and improve security.  

<br/>

- **Extending monitoring** (application logs, additional metrics, custom dashboards) to better anticipate issues and track application usage. 
<br/>
<br/>
<br/>

## 8. References
<a name="#8-references"></a>   
:link:[Application Load Balancer – AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html)  
:link:[Auto Scaling Groups – AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)  
:link:[PrivateLinks – AWS Docs](https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html)  
:link:[AWS Systems Manager (SSM) – AWS Docs](https://docs.aws.amazon.com/systems-manager/)  
:link:[Amazon CloudWatch Monitoring – AWS Docs](https://docs.aws.amazon.com/cloudwatch/)  
:link:[AWS Pricing Calculator](https://calculator.aws/#/)  
:link:[AWS Free Tier](https://aws.amazon.com/free) 
