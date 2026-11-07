resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.ecr_repository_name
  }
}
