variable "aws_region" {
  description = "AWS region for every resource in this stack"
  type        = string
  default     = "eu-north-1"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository that holds the ToDoAI image"
  type        = string
  default     = "todoai"
}

variable "image_tag" {
  description = "Tag of the image the Auto Scaling Group pulls"
  type        = string
  default     = "latest"
}

variable "app_source_repo" {
  description = "Git repository the application image is built from"
  type        = string
  default     = "https://github.com/macnaer/ToDoAI.git"
}

variable "zone_name" {
  description = "Route53 hosted zone name"
  type        = string
  default     = "ezfpv.pp.ua"
}

variable "create_route53_zone" {
  description = "true = create the hosted zone, false = use an existing one (data source)"
  type        = bool
  default     = true
}

variable "hostname" {
  description = "Public hostname served by the ALB through Route53"
  type        = string
  default     = "todoai.ezfpv.pp.ua"
}

variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "ASG minimum number of instances"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "ASG maximum number of instances"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "ASG initial desired capacity"
  type        = number
  default     = 2
}

variable "requests_per_target" {
  description = "Target value for the ALBRequestCountPerTarget tracking policy"
  type        = number
  default     = 500
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/"
}
