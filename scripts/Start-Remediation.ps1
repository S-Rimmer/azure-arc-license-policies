<#
.SYNOPSIS
    Triggers a compliance scan and starts a remediation task for a policy assignment.

.PARAMETER SubscriptionId
    Target subscription.

.PARAMETER AssignmentName
    Name of the policy assignment to remediate.

.PARAMETER Scope
    Optional. Defaults to the subscription. Use a resource group scope to narrow remediation.

.EXAMPLE
    ./Start-Remediation.ps1 -SubscriptionId "<sub>" -AssignmentName "configure-arc-sql-license-type"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [Parameter(Mandatory = $true)][string]$AssignmentName,
    [string]$Scope
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Subscription $SubscriptionId | Out-Null
if (-not $Scope) { $Scope = "/subscriptions/$SubscriptionId" }

$assignment = Get-AzPolicyAssignment -Name $AssignmentName

Write-Host "Triggering compliance scan (this can take several minutes)..." -ForegroundColor Cyan
Start-AzPolicyComplianceScan

$remediationName = "$AssignmentName-$(Get-Date -Format 'yyyyMMddHHmmss')"
Write-Host "Starting remediation '$remediationName'..." -ForegroundColor Cyan
Start-AzPolicyRemediation `
    -Name $remediationName `
    -PolicyAssignmentId $assignment.PolicyAssignmentId `
    -Scope $Scope | Out-Null

Write-Host "Remediation '$remediationName' started." -ForegroundColor Green
Write-Host "Check status with:" -ForegroundColor Yellow
Write-Host "  Get-AzPolicyRemediation -Name '$remediationName' -Scope '$Scope' -IncludeDetail"
