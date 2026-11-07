output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Direct URL to the application through the ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository the image is pushed to"
  value       = aws_ecr_repository.app.repository_url
}

output "hostname" {
  description = "Public hostname served by Route53"
  value       = var.hostname
}

output "hostname_url" {
  description = "Public URL of the application"
  value       = "http://${var.hostname}"
}

output "route53_nameservers" {
  description = "Delegate the zone to these NS records at your registrar"
  value       = var.create_route53_zone ? aws_route53_zone.this[0].name_servers : null
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "scaling_policy_name" {
  description = "Target tracking autoscaling policy attached to the ASG"
  value       = aws_autoscaling_policy.requests_per_target.name
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.app.arn
}
