<#
.SYNOPSIS
  Clones ToDoAI (if needed), builds the Docker image and pushes it to ECR.
  Run after: terraform apply -target=aws_ecr_repository.app
#>
param(
    [string]$Region = "eu-north-1",
    [string]$RepoName = "todoai",
    [string]$Tag = "latest"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param([string]$File, [string[]]$ArgList)
    & $File @ArgList
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $File $($ArgList -join ' ')" }
}

# 1. Application source
$AppDir = Join-Path $Root "app"
if (-not (Test-Path (Join-Path $AppDir ".git"))) {
    Write-Host "[1/4] Cloning ToDoAI..."
    Invoke-Checked "git" @("clone", "https://github.com/macnaer/ToDoAI.git", $AppDir)
} else {
    Write-Host "[1/4] app/ already cloned"
}

# 2. Resolve ECR URI from Terraform output
Write-Host "[2/4] Reading Terraform outputs..."
$EcrUrl = (& terraform "-chdir=$(Join-Path $Root 'terraform')" output -raw ecr_repository_url).Trim()
if (-not $EcrUrl) { throw "terraform output ecr_repository_url is empty" }
$Image = "${EcrUrl}:${Tag}"

# 3. Docker login
Write-Host "[3/4] Logging in to ECR..."
$AccountId = (& aws sts get-caller-identity --query Account --output text).Trim()
$Registry = "${AccountId}.dkr.ecr.${Region}.amazonaws.com"
$Password = (& aws ecr get-login-password --region $Region).Trim()
if (-not $Password) { throw "aws ecr get-login-password returned nothing" }
$Password | & docker login --username AWS --password-stdin $Registry
if ($LASTEXITCODE -ne 0) { throw "docker login failed" }

# 4. Build and push
Write-Host "[4/4] Building and pushing $Image ..."
Invoke-Checked "docker" @(
    "build",
    "-f", (Join-Path $Root "docker\Dockerfile"),
    "-t", $Image,
    $Root
)
Invoke-Checked "docker" @("push", $Image)

Write-Host "`nPushed: $Image"
