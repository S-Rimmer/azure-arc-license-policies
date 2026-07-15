<#
.SYNOPSIS
    Assigns an Arc license policy definition with a system-assigned managed identity
    and grants the identity the least-privilege roles needed for remediation.

.PARAMETER SubscriptionId
    Target subscription.

.PARAMETER PolicyName
    Name of the policy definition to assign (e.g. 'activate-azure-benefits-windows-arc'
    or 'configure-arc-sql-license-type').

.PARAMETER AssignmentName
    Optional assignment name. Defaults to the policy name.

.PARAMETER Location
    Region for the assignment's managed identity (required for identity assignments).

.PARAMETER Scope
    Optional. Defaults to the subscription. Can be a resource group or MG scope.

.PARAMETER RoleDefinitionIds
    Optional. One or more built-in role GUIDs to grant the assignment's managed identity. These
    must cover the roleDefinitionIds in the policy definition. Defaults to the least-privilege roles
    used by the Arc license policies: Azure Connected Machine Resource Administrator
    ('cd570a14-e51a-42ad-bac8-bafd67325302') and Reader ('acdd72a7-3385-48ef-bd42-f606fba81ae7').
    Roles are only needed when assigning a DeployIfNotExists effect; AuditIfNotExists needs none.

.PARAMETER PolicyParameterFile
    Optional. Path to a policy assignment parameters JSON file (e.g. one of the files under
    ./examples). Lets you set effect, targetLicenseType, and licenseTypesToOverwrite without
    editing the definition.

.PARAMETER SkipRoleAssignment
    Optional switch. Skips granting roles to the managed identity. Use for AuditIfNotExists
    assignments, which deploy nothing and need no permissions.

.EXAMPLE
    # Audit-only, safe first pass (no changes, no roles needed)
    ./New-Assignment.ps1 -SubscriptionId "<sub>" -PolicyName "configure-arc-sql-license-type" `
      -Location "eastus" -PolicyParameterFile ../examples/sql-license-type.audit.parameters.json `
      -SkipRoleAssignment

.EXAMPLE
    # Enforce, only stamping instances with no license type set yet
    ./New-Assignment.ps1 -SubscriptionId "<sub>" -PolicyName "configure-arc-sql-license-type" `
      -Location "eastus" -PolicyParameterFile ../examples/sql-license-type.enforce-unspecified.parameters.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [Parameter(Mandatory = $true)][string]$PolicyName,
    [string]$AssignmentName,
    [Parameter(Mandatory = $true)][string]$Location,
    [string]$Scope,
    [string[]]$RoleDefinitionIds = @('cd570a14-e51a-42ad-bac8-bafd67325302', 'acdd72a7-3385-48ef-bd42-f606fba81ae7'),
    [string]$PolicyParameterFile,
    [switch]$SkipRoleAssignment
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Subscription $SubscriptionId | Out-Null

if (-not $AssignmentName) { $AssignmentName = $PolicyName }
if (-not $Scope) { $Scope = "/subscriptions/$SubscriptionId" }

$definition = Get-AzPolicyDefinition -Name $PolicyName

$assignmentArgs = @{
    Name             = $AssignmentName
    PolicyDefinition = $definition
    Scope            = $Scope
    IdentityType     = 'SystemAssigned'
    Location         = $Location
}
if ($PolicyParameterFile) {
    if (-not (Test-Path $PolicyParameterFile)) { throw "PolicyParameterFile not found: $PolicyParameterFile" }
    $assignmentArgs['PolicyParameter'] = (Resolve-Path $PolicyParameterFile).Path
}

Write-Host "Creating assignment '$AssignmentName' at scope '$Scope'..." -ForegroundColor Cyan
$assignment = New-AzPolicyAssignment @assignmentArgs

if ($SkipRoleAssignment) {
    Write-Host "Skipping role assignment (-SkipRoleAssignment specified; use for AuditIfNotExists)." -ForegroundColor Yellow
    Write-Host "Assignment '$AssignmentName' created." -ForegroundColor Green
}
else {
    Write-Host "Waiting for managed identity to propagate..." -ForegroundColor Cyan
    Start-Sleep -Seconds 20

    foreach ($roleId in $RoleDefinitionIds) {
        Write-Host "Granting role '$roleId' to the assignment identity..." -ForegroundColor Cyan
        New-AzRoleAssignment `
            -ObjectId $assignment.Identity.PrincipalId `
            -RoleDefinitionId $roleId `
            -Scope $Scope | Out-Null
    }

    Write-Host "Assignment '$AssignmentName' created and role(s) granted." -ForegroundColor Green
}
