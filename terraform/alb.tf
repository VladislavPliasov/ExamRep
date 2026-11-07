# ---------------------------------------------------------------------------
# Application Load Balancer
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "todoai-alb-sg"
  description = "ALB - HTTP from the internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "todoai-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "todoai-app-sg"
  description = "EC2 instances - HTTP only from the ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "todoai-app-sg"
  }
}

resource "aws_lb" "main" {
  name               = "todoai-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "todoai-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "todoai-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = {
    Name = "todoai-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
