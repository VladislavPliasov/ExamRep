# AGENTS.md — AI-agent workflow for creating & verifying the infrastructure

This repository was created and is verified by an AI agent (opencode). Follow this workflow
when working on it. **Never commit secrets** (AWS keys, PATs, `.tfvars` with credentials).

## Ground rules

- AWS credentials come only from the environment (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
  or `AWS_PROFILE`). Refuse to hardcode them into any `.tf` file.
- Region: `eu-north-1` for every resource.
- Do not add ECS/Amplify/S3/second-region resources — the task scope is
  Docker image → ECR → ALB + ASG autoscaling policy → Route53.
- App source (`app/`) is a gitignored clone of `https://github.com/macnaer/ToDoAI.git`.

## Order of operations

1. **Prereqs** — `scripts/00-prereqs.ps1`; Docker engine must be running;
   `aws sts get-caller-identity` must succeed.
2. **Init/validate** — `terraform -chdir=terraform init`, `terraform validate`, `terraform fmt -check`.
3. **Preflight** (read-only checks before first apply):
   - `aws route53 list-hosted-zones-by-name --dns-name ezfpv.pp.ua`
     → zone exists ⇒ set `create_route53_zone = false` in `terraform.tfvars`
     → zone missing ⇒ keep `true` (default) and remember NS re-delegation is required.
   - `aws ec2 describe-subnets --filters Name=vpc-id,Values=<default-vpc>` ⇒ ≥2 public subnets.
4. **Phase 1** — `terraform -chdir=terraform apply -target=aws_ecr_repository.app`.
5. **Image** — `scripts/build-push.ps1` (clone → build nginx image → push `:latest`).
6. **Phase 2** — full `terraform -chdir=terraform apply` (ALB, ASG, policy, Route53 record).
7. **Verify** — `scripts/verify.ps1`, which asserts:
   - `terraform validate` passes
   - `http://<alb-dns>` returns 200
   - `http://todoai.ezfpv.pp.ua` returns 200 (needs NS delegation; may fail before that)
   - ASG has ≥1 running instance
   - target tracking policy `todoai-requests-per-target` is attached
   - ECR contains ≥1 image
8. **Scale test (optional)** — `aws autoscaling set-desired-capacity ... --desired-capacity 3`,
   confirm instance count grows, then set back to `2`.
9. **Commit** — stage only intended files (`git status` review), never `terraform.tfstate*`,
   never `terraform.tfvars`, never `app/`.

## Expected resource map

| File | Resources |
|------|-----------|
| `ecr.tf` | `aws_ecr_repository.app` |
| `alb.tf` | `aws_security_group.alb`, `aws_security_group.app`, `aws_lb.main`, `aws_lb_target_group.app`, `aws_lb_listener.http` |
| `asg.tf` | `aws_iam_role.ec2`, 2× attachments, `aws_iam_instance_profile.ec2`, `aws_launch_template.app`, `aws_autoscaling_group.app` |
| `autoscaling.tf` | `aws_autoscaling_policy.requests_per_target` |
| `route53.tf` | `aws_route53_zone.this` (or data source), `aws_route53_record.app` |

## Failure playbook

- `docker login` / push fails ⇒ Docker Desktop not running, or ECR repo missing (step 4).
- Instances unhealthy in TG ⇒ check `/var/log/cloud-init-output.log` on the instance via SSM;
  usually ECR pull permissions or image not pushed yet.
- Hostname does not resolve ⇒ NS delegation not set at pp.ua registrar (output `route53_nameservers`);
  ALB URL still works.
- `terraform apply` wants to replace ASG instances ⇒ expected after launch-template/user_data
  change (`instance_refresh` with `triggers = ["launch_template"]` handles the rollout).
- `PutScalingPolicy` → `Invalid resource label` ⇒ `ALBRequestCountPerTarget` needs
  `"<lb.arn_suffix>/<tg.arn_suffix>"` (both parts), not the TG suffix alone.
- `iam:CreateInstanceProfile` denied ⇒ the `admin` user needs the scoped instance-profile
  policy (see README) before the ASG part can apply.

## Verification transcript (filled 2026-11-07)

```
terraform validate : OK
ALB URL            : 200 (http://todoai-alb-311065274.eu-north-1.elb.amazonaws.com)
hostname           : PENDING NS delegation - set these at the pp.ua registrar:
                       ns-1290.awsdns-33.org
                       ns-1874.awsdns-42.co.uk
                       ns-403.awsdns-50.com
                       ns-734.awsdns-27.net
ASG instances      : 2 desired → scale test 1→3 OK → back to min 1
policy attached    : todoai-requests-per-target (ALBRequestCountPerTarget, target 500)
ECR images         : 1 (todoai:latest, sha256:5eb5b32a...)
target health      : i-0e56bc507aa010d42 healthy
```
