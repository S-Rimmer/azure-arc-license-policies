# Azure Arc Governance — Windows AHB & SQL License Policies

## Overview

Two custom Azure Policy definitions enforce licensing posture on the Azure Arc–enabled estate:

| # | Policy | Target resource | Effect | Purpose |
|---|--------|-----------------|--------|---------|
| 1 | **Activate Azure Benefits for Windows Arc Machines** | `Microsoft.HybridCompute/machines` | DeployIfNotExists | Enables Software Assurance / Azure Hybrid Benefit on licensed Windows Server Arc machines |
| 2 | **Set Arc SQL Server License Type** | `Microsoft.AzureArcData/sqlServerInstances` (detect) → `Microsoft.HybridCompute/machines/extensions` (remediate) | DeployIfNotExists | Sets SQL Server license type via the SQL Server extension |

Both use a system-assigned managed identity with **Contributor** at the assignment scope and require a **remediation task** to bring existing resources into compliance (DINE only auto-triggers on resource create/update).

## Policy 1 — Windows Azure Hybrid Benefit

- Scope: `osType = windows` and `licenseProfile.licenseStatus = Licensed` (unlicensed servers are intentionally skipped).
- Remediation writes `licenseProfile.softwareAssurance.softwareAssuranceCustomer = true` via the `machines/licenseProfiles` resource.
- **Design note:** the definition is deliberately **version-agnostic**. Earlier 2025-specific logic (Pay-as-you-go `productProfile`) was removed because those fields do not exist on 2016/2019/2022 builds and caused null-parameter deployment failures — the symptom being "only 2025 machines remediate." The current single-condition design applies uniformly to all supported Windows Server versions.

## Policy 2 — SQL Server License Type

### Key technical difference (important)

`Microsoft.AzureArcData/sqlServerInstances.licenseType` is a **read-only projection** — it reports the license type but cannot be written directly. The authoritative setting lives in the **Azure extension for SQL Server** (`WindowsAgent.SqlServer`, publisher `Microsoft.AzureData`) as `settings.LicenseType`.

Consequently, the policy **detects** non-compliance on the `sqlServerInstances` resource (where `licenseType` is readable) but **remediates** by deploying the SQL Server extension with `settings.LicenseType = Paid`. A common early mistake is to target the `sqlServerInstances` resource for remediation — that deployment does not persist because the value is owned by the extension.

### Operational caveats

- **Extension settings are overwritten** on deployment. Any custom settings (SQL instance exclusion lists, `ConsentToRecurringPAYG`, patching/ESU config) not included in the template are lost. The policy sends only `LicenseType` and `SqlManagement.IsEnabled = true`.
- **Uniform application:** the policy sets one license type for all in-scope instances. **Server+CAL–licensed instances must remain `LicenseOnly`** and should be excluded via the exclusion tag.
- An **exclusion tag** parameter (`ExcludeFromSqlLicensePolicy = true` on the SQL instance resource) allows opting individual instances out of evaluation/remediation.
- After remediation, the `sqlServerInstances.licenseType` projection updates only after the extension reports back (projection lag of minutes up to ~1 hour).

## The three options for setting SQL license type

| Option | Mechanism | Best for | Key limitations |
|--------|-----------|----------|-----------------|
| **A. Azure Policy (DINE)** | Deploys `WindowsAgent.SqlServer` extension with `LicenseType` | Continuous governance, drift detection/correction across the estate | Overwrites extension settings; applies one value uniformly; no awareness of Server+CAL or PAYG consent |
| **B. Onboarding tag** — `ArcSQLServerExtensionDeployment = Paid` / `PAYG` on subscription/RG/machine | Honored by the SQL auto-deploy workflow at onboarding | Governing **new** instances as they connect | Does **not** change already-onboarded instances; onboarding-time only |
| **C. `modify-license-type.ps1`** (Microsoft SQL samples) | Updates the extension while **preserving** existing settings and registering PAYG consent | Bulk changes to **existing** fleet and license-agreement transitions | Manual/scheduled execution; not continuous enforcement |

## Recommended approach

A layered model rather than any single mechanism:

1. **New onboarding → Option B (tag).** Set `ArcSQLServerExtensionDeployment` on the subscription/RG so every newly connected SQL instance gets the correct license type automatically. Use `PAYG-Recurring` for CSP-managed subscriptions (records required consent).
2. **Existing fleet & transitions → Option C (script).** Use Microsoft's supported [`modify-license-type.ps1`](https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/azure-arc-enabled-sql-server/modify-license-type) for the initial bulk change and for any Software Assurance/subscription → PAYG transitions. It preserves existing extension settings and handles consent — the two things the policy cannot do.
3. **Ongoing compliance → Option A (policy).** Run Policy 2 in **`AuditIfNotExists`** mode as the estate-wide compliance monitor/reporting control. Only promote specific scopes to **`DeployIfNotExists`** where machines have **no custom extension settings** and are confirmed BYOL/SA-entitled, and always pair enforcement with the **exclusion tag** to protect instances with exclusion lists, PAYG consent, or Server+CAL licensing.

**Rationale:** the PowerShell script is the safest instrument for changing values on existing machines because it is non-destructive to other extension settings and understands billing consent; the policy is the right instrument for *visibility and drift prevention*, not for the initial bulk mutation. Using DINE as the primary change tool across a heterogeneous fleet risks clobbering exclusion lists/consent and mislabeling Server+CAL instances.

## Licensing correctness note

`Paid` asserts coverage by SQL Server Software Assurance or a subscription license (BYOL). Applying `Paid` to instances without that entitlement misrepresents licensing; `PAYG` bills hourly through Azure. License type selection must align with actual entitlement per instance.

## References

- Configure SQL Server enabled by Azure Arc — <https://learn.microsoft.com/sql/sql-server/azure-arc/manage-configuration>
- Manage licensing and billing of SQL Server enabled by Azure Arc — <https://learn.microsoft.com/sql/sql-server/azure-arc/manage-license-billing>
- Move SQL Server license agreement to pay-as-you-go subscription — <https://learn.microsoft.com/sql/sql-server/azure-arc/manage-pay-as-you-go-transition>
- Set license type for automatically connected SQL Servers (tags) — <https://learn.microsoft.com/sql/sql-server/azure-arc/manage-autodeploy>
- `modify-license-type.ps1` (SQL Server samples) — <https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/azure-arc-enabled-sql-server/modify-license-type>
