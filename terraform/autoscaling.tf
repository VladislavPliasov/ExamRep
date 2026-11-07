# ---------------------------------------------------------------------------
# Autoscaling policy: ALB request count per target (target tracking)
# Scales the ASG so each target handles ~var.requests_per_target requests
# within the CloudWatch metric period.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "requests_per_target" {
  name                   = "todoai-requests-per-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      # Required format: app/<lb-name>/<lb-id>/targetgroup/<tg-name>/<tg-id>
      resource_label = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }

    target_value     = var.requests_per_target
    disable_scale_in = false
  }
}
