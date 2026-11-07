provider "aws" {
  region = var.aws_region

  # Credentials come exclusively from the environment:
  #   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  (or AWS_PROFILE / AWS_SESSION_TOKEN)
  # Never hardcode keys in this repository.
}
