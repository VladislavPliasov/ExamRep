# ExamRep — ToDoAI on AWS (Docker → ECR → ALB + ASG → Route53)

![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5-purple)
![AWS](https://img.shields.io/badge/AWS-EC2%20%C2%B7%20ECR%20%C2%B7%20ALB%20%C2%B7%20Route53-orange)
![Docker](https://img.shields.io/badge/Docker-image%20%2B%20ECR-blue)

Deploys the [ToDoAI](https://github.com/macnaer/ToDoAI) task manager as a Docker container on an
**EC2 Auto Scaling Group** behind an **Application Load Balancer**, with an **autoscaling policy**
and public DNS through **Route53**.

## Architecture

```
                       ┌────────────────────────────────────────────────┐
                       │                 Route53                        │
                       │  todoai.ezfpv.pp.ua  (alias A, health-aware)   │
                       └───────────────────────┬────────────────────────┘
                                               │
┌──────────────────────────────────────────────▼──────────────────────────────┐
│ AWS eu-north-1, default VPC (public subnets)                                │
│                                                                             │
│  ┌──────────────────────────┐        ┌───────────────────────────────────┐  │
│  │  Application Load        │  HTTP  │  EC2 Auto Scaling Group           │  │
│  │  Balancer (internet-     │───────►│  min 1 / desired 2 / max 4        │  │
│  │  facing, port 80)        │ :80    │  Amazon Linux 2023, t3.micro      │  │
│  │  SG: 80 from 0.0.0.0/0   │        │  user_data: docker pull + run     │  │
│  └──────────────────────────┘        │  SG: 80 only from ALB SG          │  │
│           │                          └─────────────────┬─────────────────┘  │
│           │ target group (health check / → 200)       │ IAM: ECR read + SSM│
│           │                          ┌─────────────────▼─────────────────┐  │
│           │                          │  Amazon ECR: todoai (:latest)     │  │
│           │                          │  built by scripts/build-push.ps1  │  │
│           │                          └───────────────────────────────────┘  │
│           │                                                                  │
│  ┌────────▼─────────────────────────────────────────────────────────────┐   │
│  │ Autoscaling policy: TargetTrackingScaling                            │   │
│  │ metric = ALBRequestCountPerTarget, target = 500 requests/target      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Repository layout

| Path | Purpose |
|------|---------|
| `docker/Dockerfile` | Multi-stage build: `node:20` → `nginx:1.27` (~30 MB image) |
| `docker/nginx.conf` | SPA fallback, asset caching, gzip |
| `scripts/00-prereqs.ps1` | Installs AWS CLI v2 + Docker Desktop via winget |
| `scripts/build-push.ps1` | Clones ToDoAI, builds image, pushes to ECR |
| `scripts/verify.ps1` | Full verification (validate, HTTP, ASG, policy, ECR) |
| `terraform/` | All infrastructure as code |
| `terraform/templates/user_data.sh.tpl` | Boot script: install docker, pull from ECR, run |
| `AGENTS.md` | Workflow used by the AI agent to create & verify the stack |

## Prerequisites

- Terraform >= 1.5
- Docker Desktop (engine running)
- AWS CLI v2
- AWS credentials **in environment variables** (never in files):

```powershell
$env:AWS_ACCESS_KEY_ID     = "..."
$env:AWS_SECRET_ACCESS_KEY = "..."
aws sts get-caller-identity   # must print your account id
```

## Quick start

```powershell
# 0. tooling (once)
.\scripts\00-prereqs.ps1

# 1. create the ECR repository first (image push needs it)
terraform -chdir=terraform init
terraform -chdir=terraform apply -target=aws_ecr_repository.app

# 2. build the Docker image and push it to ECR
.\scripts\build-push.ps1

# 3. everything else: ALB, ASG, autoscaling policy, Route53
terraform -chdir=terraform apply

# 4. verify
.\scripts\verify.ps1
```

## DNS setup (manual, once)

`terraform apply` prints `route53_nameservers`. Log in to your **pp.ua** registrar and set the
delegation for `ezfpv.pp.ua` to those 4 name servers. Until then the ALB URL
(`alb_url` output) already works; the hostname starts resolving after propagation (minutes to hours).

## Autoscaling

`terraform/autoscaling.tf` attaches a **target tracking** policy to the ASG:

- metric: `ALBRequestCountPerTarget` (CloudWatch, fed by the ALB target group)
- target: `requests_per_target` = 500 (variable)
- `min_size = 1`, `desired_capacity = 2`, `max_size = 4`

Test manually:

```powershell
aws autoscaling set-desired-capacity --region eu-north-1 `
  --auto-scaling-group-name todoai-asg --desired-capacity 3
```

## Cleanup

```powershell
terraform -chdir=terraform destroy
```

ECR uses `force_delete = true`, so the repository (and images) are removed with the stack.
Route53 hosted zone deletion requires that no non-default records remain — destroy handles that.

## Security notes

- No AWS keys, tokens or passwords are stored in this repository. Credentials come from the
  environment; `terraform.tfvars` is gitignored.
- Instances are **not** SSH-opened; management is via AWS SSM (`AmazonSSMManagedInstanceCore`).
- Instances accept port 80 **only from the ALB security group**.
- If you previously committed AWS keys anywhere, treat them as leaked and rotate them.
