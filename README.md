# Azure Arc License Policies

Reusable Azure Policy definitions for governing licensing posture across an **Azure Arc–enabled** estate:

| Policy | Folder | Purpose |
|--------|--------|---------|
| **Activate Azure Benefits for Windows Arc Machines** | [`policies/windows-azure-hybrid-benefit`](policies/windows-azure-hybrid-benefit) | Enables Software Assurance / Azure Hybrid Benefit on licensed Windows Server Arc machines (all versions) |
| **Set Arc SQL License Type** | [`policies/sql-license-type`](policies/sql-license-type) | Sets SQL Server license type (`Paid` / `PAYG` / `LicenseOnly`) via the SQL Server extension |

> Full background, the read-only-projection nuance for SQL `licenseType`, and the recommended layered approach are in [`docs/technical-overview.md`](docs/technical-overview.md).

## Repository layout

```
azure-arc-license-policies/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
│   └── technical-overview.md
├── policies/
│   ├── windows-azure-hybrid-benefit/
│   │   ├── azurepolicy.json            # full definition (properties)
│   │   ├── azurepolicy.rules.json      # policyRule only (az CLI --rules)
│   │   ├── azurepolicy.parameters.json # parameters only (az CLI --params)
│   │   └── README.md
│   └── sql-license-type/
│       ├── azurepolicy.json
│       ├── azurepolicy.rules.json
│       ├── azurepolicy.parameters.json
│       └── README.md
└── scripts/
    ├── Deploy-Policies.ps1     # create/update both definitions
    ├── New-Assignment.ps1      # assign with system-assigned identity + role
    └── Start-Remediation.ps1   # scan + remediate
```

## Prerequisites

- Azure PowerShell (`Az.Resources`, `Az.PolicyInsights`) or Azure CLI.
- Rights to create policy definitions/assignments and role assignments at the target scope (Owner or User Access Administrator + Resource Policy Contributor).
- Azure Arc–enabled servers onboarded; for SQL, the **Azure extension for SQL Server** installed.

## Quick start

```powershell
# 1. Create/update both policy definitions at a subscription
./scripts/Deploy-Policies.ps1 -SubscriptionId "<sub-id>"

# 2. Assign a policy (creates system-assigned identity + grants role)
./scripts/New-Assignment.ps1 -SubscriptionId "<sub-id>" `
  -PolicyName "activate-azure-benefits-windows-arc" -Location "eastus"

# 3. Evaluate + remediate existing resources
./scripts/Start-Remediation.ps1 -SubscriptionId "<sub-id>" `
  -AssignmentName "activate-azure-benefits-windows-arc"
```

## Recommended rollout

1. Assign with `effect = AuditIfNotExists` first and review compliance.
2. Tag any exceptions (e.g., SQL Server+CAL instances) so they are skipped.
3. Promote to `DeployIfNotExists` and run remediation.

See each policy's `README.md` for parameters, caveats, and per-policy remediation notes.

## Disclaimer

These definitions are provided as-is under the [MIT License](LICENSE). Validate in a non-production scope before broad assignment. `Paid` asserts the resource is covered by Software Assurance / a subscription license — align license type with actual entitlement.
