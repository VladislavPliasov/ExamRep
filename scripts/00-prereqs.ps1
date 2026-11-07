<#
.SYNOPSIS
  Installs the tooling required by this repository (idempotent).
.NOTES
  Run from an elevated PowerShell if winget requires administrator rights.
#>
$ErrorActionPreference = "Stop"

$packages = @(
    @{ Id = "Amazon.AWSCLI";      Name = "AWS CLI v2" },
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" }
)

foreach ($p in $packages) {
    $installed = winget list --id $p.Id -e --accept-source-agreements 2>$null | Select-String -Pattern $p.Id
    if ($installed) {
        Write-Host "[skip] $($p.Name) already installed"
    } else {
        Write-Host "[install] $($p.Name)..."
        winget install --id $p.Id -e --accept-source-agreements --accept-package-agreements --disable-interactivity
    }
}

Write-Host "`nNext steps:"
Write-Host "  1. Start Docker Desktop and wait until the engine is running"
Write-Host "  2. export AWS_ACCESS_KEY_ID=... ; export AWS_SECRET_ACCESS_KEY=..."
Write-Host "  3. aws sts get-caller-identity"
