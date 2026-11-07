<#
.SYNOPSIS
  Verifies the infrastructure defined in ./terraform:
  - terraform validate
  - ALB answers over HTTP
  - Route53 hostname answers over HTTP
  - ASG has healthy instances
  - Autoscaling policy is attached
#>
param(
    [string]$Region = "eu-north-1"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$TfDir = Join-Path $Root "terraform"
$Failures = @()

function Check {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        if ($result) { Write-Host "[OK]   $Name" }
        else { Write-Host "[FAIL] $Name"; $script:Failures += $Name }
    } catch {
        Write-Host "[FAIL] $Name - $($_.Exception.Message)"
        $script:Failures += $Name
    }
}

Write-Host "== terraform validate =="
terraform "-chdir=$TfDir" validate
if ($LASTEXITCODE -ne 0) { $Failures += "terraform validate" }

function TfOut([string]$Name) {
    (terraform "-chdir=$TfDir" output -raw $Name 2>$null).Trim()
}

$AlbUrl     = TfOut "alb_url"
$HostnameUrl = TfOut "hostname_url"
$AsgName    = TfOut "asg_name"
$PolicyName = TfOut "scaling_policy_name"

Check "ALB responds ($AlbUrl)" {
    $r = Invoke-WebRequest -Uri $AlbUrl -UseBasicParsing -TimeoutSec 20
    $r.StatusCode -eq 200 -and $r.Content.Length -gt 0
}

Check "Route53 hostname responds ($HostnameUrl)" {
    $r = Invoke-WebRequest -Uri $HostnameUrl -UseBasicParsing -TimeoutSec 20
    $r.StatusCode -eq 200 -and $r.Content.Length -gt 0
}

Check "ASG has running instances" {
    $g = aws autoscaling describe-auto-scaling-groups `
        --region $Region `
        --auto-scaling-group-names $AsgName `
        --query "AutoScalingGroups[0].{d:DesiredCapacity,i:length(Instances)}" `
        --output json | ConvertFrom-Json
    ($g.i -ge 1) -and ($g.d -ge 1)
}

Check "Target tracking policy attached" {
    $p = aws autoscaling describe-policies `
        --region $Region `
        --auto-scaling-group-name $AsgName `
        --query "ScalingPolicies[?PolicyName=='$PolicyName']" `
        --output json | ConvertFrom-Json
    $null -ne $p -and $p.Count -ge 1
}

Check "ECR image exists" {
    $repo = TfOut "ecr_repository_url"
    $count = aws ecr describe-images --region $Region --repository-name todoai `
        --query "length(imageDetails)" --output text
    [int]$count -ge 1
}

Write-Host ""
if ($Failures.Count -eq 0) {
    Write-Host "All checks passed."
} else {
    Write-Host "Failed checks:"
    $Failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
