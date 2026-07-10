# Set Arc SQL Server License Type

Detects **Azure Arc–enabled SQL Server instances** and sets their license type (default `Paid`) by deploying the **SQL Server extension** with the correct `LicenseType` setting.

## Key technical point

`Microsoft.AzureArcData/sqlServerInstances.licenseType` is a **read-only projection**. It cannot be written directly — the authoritative value lives in the **Azure extension for SQL Server** (`WindowsAgent.SqlServer`, publisher `Microsoft.AzureData`) as `settings.LicenseType`.

Therefore this policy:
- **Detects** on `sqlServerInstances` (where `licenseType` is readable), and
- **Remediates** by deploying `Microsoft.HybridCompute/machines/extensions/WindowsAgent.SqlServer` with `settings.LicenseType`.

Targeting the `sqlServerInstances` resource for remediation does **not** work — the write does not persist.

## What it does

| Aspect | Value |
|--------|-------|
| Detect target | `Microsoft.AzureArcData/sqlServerInstances` |
| Remediate target | `Microsoft.HybridCompute/machines/extensions` (`WindowsAgent.SqlServer`) |
| Effect | `DeployIfNotExists` (default), `AuditIfNotExists`, `Disabled` |
| Compliance check | `sqlServerInstances/licenseType = <licenseType>` |
| Role required | Contributor (`b24988ac-6180-42a0-ab88-20f7382dd24c`) |

## Parameters

| Name | Allowed values | Default | Notes |
|------|----------------|---------|-------|
| `effect` | `DeployIfNotExists`, `AuditIfNotExists`, `Disabled` | `DeployIfNotExists` | Start with `AuditIfNotExists`. |
| `licenseType` | `Paid`, `PAYG`, `LicenseOnly` | `Paid` | `Paid` = BYOL with SA/subscription; `PAYG` = hourly Azure billing. |
| `exclusionTagName` | string | `ExcludeFromSqlLicensePolicy` | Tag on the **SQL instance resource** used to opt out. |
| `exclusionTagValue` | string | `true` | Value that triggers exclusion. |

## Caveats (read before enforcing)

1. **Extension settings are overwritten.** The deployment sends only `LicenseType` and `SqlManagement.IsEnabled = true`. Existing custom settings (exclusion lists, `ConsentToRecurringPAYG`, patching/ESU config) are lost. For machines with custom settings, prefer the [`modify-license-type.ps1`](https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/azure-arc-enabled-sql-server/modify-license-type) script (preserves settings).
2. **Server+CAL instances must stay `LicenseOnly`** — exclude them via the exclusion tag.
3. **Projection lag.** After remediation, `sqlServerInstances.licenseType` updates only once the extension reports back (minutes up to ~1 hour). Re-run a compliance scan afterward.
4. **Assumes** the SQL instance resource name equals the host machine name (true for Arc auto-onboarded SQL) and that the extension resource is named `WindowsAgent.SqlServer`. Verify with:
   ```powershell
   az connectedmachine extension list --machine-name "<machine>" -g "<rg>" `
     --query "[].{name:name, type:properties.type, publisher:properties.publisher, license:properties.settings.LicenseType}" -o table
   ```

## Exclude an instance

```powershell
$sql = Get-AzResource -ResourceType "Microsoft.AzureArcData/sqlServerInstances" -Name "<instance>"
Update-AzTag -ResourceId $sql.ResourceId -Tag @{ ExcludeFromSqlLicensePolicy = "true" } -Operation Merge
```

## Deploy

```powershell
az policy definition create `
  --name "set-arc-sql-license-type" `
  --display-name "Set Arc SQL Server License Type" `
  --description "Sets SQL license type on Arc-enabled SQL Server instances via the WindowsAgent.SqlServer extension." `
  --rules "@azurepolicy.rules.json" `
  --params "@azurepolicy.parameters.json" `
  --mode Indexed
```

## Relationship to the other options

This policy is one of three ways to set SQL license type. See [`docs/technical-overview.md`](../../docs/technical-overview.md) for the full comparison and the recommended layered approach (onboarding tag for new servers, `modify-license-type.ps1` for existing/bulk, policy for compliance/drift).
