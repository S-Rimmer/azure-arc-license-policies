<#
.SYNOPSIS
    Creates or updates the Azure Arc license policy definitions in a subscription.

.DESCRIPTION
    Reads the azurepolicy.rules.json / azurepolicy.parameters.json for each policy
    and creates/updates the definition (idempotent upsert by -Name).

.PARAMETER SubscriptionId
    Target subscription for the policy definitions.

.EXAMPLE
    ./Deploy-Policies.ps1 -SubscriptionId "00000000-0000-0000-0000-000000000000"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'
Set-AzContext -Subscription $SubscriptionId | Out-Null

$repoRoot = Split-Path $PSScriptRoot -Parent

$definitions = @(
    @{
        Name        = 'activate-azure-benefits-windows-arc'
        DisplayName = 'Activate Azure Benefits for Windows Arc Machines'
        Description = 'Enables Software Assurance (Azure Hybrid Benefit) for licensed Windows Server Azure Arc machines of any version.'
        Folder      = 'windows-azure-hybrid-benefit'
    },
    @{
        Name        = 'set-arc-sql-license-type'
        DisplayName = 'Set Arc SQL Server License Type'
        Description = 'Sets SQL license type on Arc-enabled SQL Server instances via the WindowsAgent.SqlServer extension.'
        Folder      = 'sql-license-type'
    }
)

foreach ($def in $definitions) {
    $base   = Join-Path $repoRoot "policies/$($def.Folder)"
    $rules  = Get-Content (Join-Path $base 'azurepolicy.rules.json') -Raw
    $params = Get-Content (Join-Path $base 'azurepolicy.parameters.json') -Raw

    Write-Host "Deploying policy definition '$($def.Name)'..." -ForegroundColor Cyan
    New-AzPolicyDefinition `
        -Name $def.Name `
        -DisplayName $def.DisplayName `
        -Description $def.Description `
        -Policy $rules `
        -Parameter $params `
        -Mode 'Indexed' | Out-Null
    Write-Host "  Done." -ForegroundColor Green
}

Write-Host "All policy definitions deployed to subscription $SubscriptionId." -ForegroundColor Green
