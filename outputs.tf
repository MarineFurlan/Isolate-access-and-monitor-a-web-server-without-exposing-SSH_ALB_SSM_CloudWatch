output "alb_dns" {
  value = module.alb.alb_dns_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alerts"
  value       = module.cloudwatch.sns_topic_arn
}

output "target_group_arn" {
  value       = module.alb.tg_arn
}

output "instance_id" {
  value       = module.cloudwatch.target_group_arn
}