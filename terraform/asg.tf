# ---------------------------------------------------------------------------
# EC2 Auto Scaling Group running the container image from ECR
# ---------------------------------------------------------------------------

locals {
  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    region     = var.aws_region
    account_id = data.aws_caller_identity.current.account_id
    repository = aws_ecr_repository.app.repository_url
    image_tag  = var.image_tag
  })
}

resource "aws_iam_role" "ec2" {
  name = "todoai-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "todoai-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "todoai-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  user_data     = base64encode(local.user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2.arn
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "todoai-asg"
    }
  }

  tags = {
    Name = "todoai-asg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "todoai-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier       = data.aws_subnets.default.ids
  target_group_arns         = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "todoai-asg"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.http]
}
