# Activate Azure Benefits for Windows Arc Machines

Enables **Software Assurance / Azure Hybrid Benefit** on licensed Windows Server machines connected to Azure Arc, across **all** Windows Server versions (2012 R2 → 2025).

## What it does

| Aspect | Value |
|--------|-------|
| Target | `Microsoft.HybridCompute/machines` |
| Effect | `DeployIfNotExists` (default), `AuditIfNotExists`, `Disabled` |
| Scope filter | `osType = windows` **and** `licenseProfile.licenseStatus = Licensed` |
| Compliance check | `licenseProfile.softwareAssurance.softwareAssuranceCustomer = true` |
| Remediation | Deploys `machines/licenseProfiles` (`default`) setting `softwareAssurance.softwareAssuranceCustomer = true` (only when the machine `status = Connected`) |
| Role required | Contributor (`b24988ac-6180-42a0-ab88-20f7382dd24c`) |

## Parameters

| Name | Allowed values | Default |
|------|----------------|---------|
| `effect` | `DeployIfNotExists`, `AuditIfNotExists`, `Disabled` | `DeployIfNotExists` |

## Design notes

- **Version-agnostic by design.** Earlier iterations included Windows Server 2025 Pay-as-you-go (`productProfile`) logic. Those fields don't exist on 2016/2019/2022, and passing their null values into required ARM template parameters caused remediation deployments to fail on non-2025 machines (symptom: "only 2025 machines remediate"). This definition uses a single Software Assurance check that applies uniformly.
- Unlicensed servers are intentionally out of scope (`licenseStatus = Licensed`).
- The deployment guards on `status = Connected` so it doesn't attempt writes against disconnected agents.

## Deploy

```powershell
az policy definition create `
  --name "activate-azure-benefits-windows-arc" `
  --display-name "Activate Azure Benefits for Windows Arc Machines" `
  --description "Enables Software Assurance (Azure Hybrid Benefit) for licensed Windows Server Azure Arc machines of any version." `
  --rules "@azurepolicy.rules.json" `
  --params "@azurepolicy.parameters.json" `
  --mode Indexed
```

## Assign (system-assigned identity) + remediate

See the repo-level [`scripts/`](../../scripts) for `New-Assignment.ps1` and `Start-Remediation.ps1`, or the root [README](../../README.md#quick-start).

## Verify

```powershell
Get-AzResource -ResourceType "Microsoft.HybridCompute/machines" -ExpandProperties |
  Select-Object Name,
    @{n='SoftwareAssurance';e={$_.Properties.licenseProfile.softwareAssurance.softwareAssuranceCustomer}}
```
