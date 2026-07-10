<#
.SYNOPSIS
    Assigns an Arc license policy definition with a system-assigned managed identity
    and grants the identity the Contributor role at the assignment scope.

.PARAMETER SubscriptionId
    Target subscription.

.PARAMETER PolicyName
    Name of the policy definition to assign (e.g. 'activate-azure-benefits-windows-arc'
    or 'set-arc-sql-license-type').

.PARAMETER AssignmentName
    Optional assignment name. Defaults to the policy name.

.PARAMETER Location
    Region for the assignment's managed identity (required for identity assignments).

.PARAMETER Scope
    Optional. Defaults to the subscription. Can be a resource group or MG scope.

.EXAMPLE
    ./New-Assignment.ps1 -SubscriptionId "<sub>" -PolicyName "set-arc-sql-license-type" -Location "eastus"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SubscriptionId,
    [Parameter(Mandatory = $true)][string]$PolicyName,
    [string]$AssignmentName,
    [Parameter(Mandatory = $true)][string]$Location,
    [string]$Scope
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Subscription $SubscriptionId | Out-Null

if (-not $AssignmentName) { $AssignmentName = $PolicyName }
if (-not $Scope) { $Scope = "/subscriptions/$SubscriptionId" }

$definition = Get-AzPolicyDefinition -Name $PolicyName

Write-Host "Creating assignment '$AssignmentName' at scope '$Scope'..." -ForegroundColor Cyan
$assignment = New-AzPolicyAssignment `
    -Name $AssignmentName `
    -PolicyDefinition $definition `
    -Scope $Scope `
    -IdentityType SystemAssigned `
    -Location $Location

# The Contributor role id referenced by the policy's roleDefinitionIds
$contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

Write-Host "Waiting for managed identity to propagate..." -ForegroundColor Cyan
Start-Sleep -Seconds 20

Write-Host "Granting Contributor to the assignment identity..." -ForegroundColor Cyan
New-AzRoleAssignment `
    -ObjectId $assignment.Identity.PrincipalId `
    -RoleDefinitionId $contributorRoleId `
    -Scope $Scope | Out-Null

Write-Host "Assignment '$AssignmentName' created and role granted." -ForegroundColor Green
