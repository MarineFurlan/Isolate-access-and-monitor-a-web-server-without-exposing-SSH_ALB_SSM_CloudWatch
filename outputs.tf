output "alb_dns" {
  value = module.alb.alb_dns_name
}

output "sns_topic_arn" {
  value = module.cloudwatch.sns_topic_arn
}

output "target_group_arn" {
  value = module.alb.tg_arn
}

/*output "instance_id" {
  value       = module.asg
}*/

output "asg_name" {
  value = module.asg.asg_name
}

output "ec2_security_group_id" {
  value = module.asg.ec2_sg_id
}

output "cloudwatch_alarm_name" {
  value = module.cloudwatch.alarm_name
}

output "alb_arn_suffix" {
  value = module.alb.alb_arn_suffix
}