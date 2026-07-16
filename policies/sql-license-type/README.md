# Configure Arc-enabled SQL Server License Type

Enforces the SQL Server license type on **Azure Arc–enabled SQL Server** instances by setting the `LicenseType` value on the SQL Server extension (`WindowsAgent.SqlServer` / `LinuxAgent.SqlServer`).

## Attribution

> **This policy definition is sourced from Microsoft's official `sql-server-samples` repository, with minor local modifications (see "Notes for this repo").**
>
> Source: [microsoft/sql-server-samples — arc-sql-license-type-compliance](https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/azure-arc-enabled-sql-server/compliance/arc-sql-license-type-compliance)
> Licensed by Microsoft under the [MIT License](https://github.com/microsoft/sql-server-samples/blob/master/license.txt).
>
> It replaces an earlier custom definition in this repo. The Microsoft version is preferred because it is non-destructive to existing extension settings and handles Pay-as-you-go consent (see below).

## Why this version

Unlike a naive definition that overwrites the extension `settings` object, this policy:

- **Preserves existing extension settings** — the remediation template reads the current settings and does `union(existingSettings, licenseSettings)`, merging only `LicenseType` (and consent). Exclusion lists, patching/ESU config, and other settings are retained.
- **Registers PAYG consent** — when `targetLicenseType = PAYG`, it sets `ConsentToRecurringPAYG` (Consented + timestamp), which is required for recurring pay-as-you-go billing (e.g., CSP-managed subscriptions).
- **Targets the extension directly** for both **Windows and Linux** SQL agents.
- Uses `evaluationDelay: AfterProvisioningSuccess` to account for reporting lag.
- Uses a least-privilege role (Azure Extension for SQL Server Deployment) — the same purpose-built role Microsoft's built-in SQL license policy uses.

## What it does

| Aspect | Value |
|--------|-------|
| Target | `Microsoft.HybridCompute/machines/extensions` where name/type is `*Agent.SqlServer` |
| Effect | `DeployIfNotExists` (default), `AuditIfNotExists`, or `Disabled` |
| Compliance check | Extension `settings.LicenseType` equals `targetLicenseType`, subject to `licenseTypesToOverwrite` |
| Remediation | Deploys the extension with `settings = union(existingSettings, { LicenseType, [ConsentToRecurringPAYG] })` |
| Roles | Azure Extension for SQL Server Deployment (`7392c568-9289-4bde-aaaa-b7131215889d`) |

## Parameters

| Name | Type | Allowed values | Default | Purpose |
|------|------|----------------|---------|---------|
| `effect` | String | `DeployIfNotExists`, `AuditIfNotExists`, `Disabled` | `DeployIfNotExists` | Policy effect |
| `sqlServerExtensionTypes` | Array | `WindowsAgent.SqlServer`, `LinuxAgent.SqlServer` | both | Which SQL agent extensions to target |
| `targetLicenseType` | String | `Paid`, `PAYG` | `Paid` | License type to enforce |
| `licenseTypesToOverwrite` | Array | `Unspecified`, `Paid`, `PAYG`, `LicenseOnly` | all | Which **current** license states are eligible for change. Use this to protect intentionally-set values (e.g., omit `LicenseOnly` to leave Server+CAL instances alone) |

> **Exclusion model:** this policy controls scope via `licenseTypesToOverwrite` (state-based), not via a tag. For example, set it to `["Unspecified"]` to only stamp instances that have no license type yet, leaving all explicitly-set values untouched.

## Notes for this repo

- Two local changes were made to Microsoft's sample: `AuditIfNotExists` was added to the `effect` allowed values (so the estate can be audited before enforcing), and remediation uses the purpose-built, least-privilege **Azure Extension for SQL Server Deployment** role (`7392c568-9289-4bde-aaaa-b7131215889d`) — the same role Microsoft's built-in SQL license policy uses. `metadata.category` is left empty as published; set a category (e.g., `Azure Arc`) at deploy time if your governance requires one.
- `azurepolicy.rules.json` and `azurepolicy.parameters.json` are generated from the definition for `az CLI` convenience.

## Deploy

```powershell
az policy definition create `
  --name "configure-arc-sql-license-type" `
  --display-name "Configure Arc-enabled SQL Server license type" `
  --description "Configures the license type for Arc-enabled SQL Server extensions to a specified target value." `
  --rules "@azurepolicy.rules.json" `
  --params "@azurepolicy.parameters.json" `
  --mode Indexed
```

## Relationship to the other options

This is Option A (Azure Policy) in the three-option model. For existing fleets and license-agreement transitions, Microsoft's [`modify-license-type.ps1`](https://github.com/microsoft/sql-server-samples/tree/master/samples/manage/azure-arc-enabled-sql-server/modify-license-type) script is still recommended for bulk changes. See [`docs/technical-overview.md`](../../docs/technical-overview.md).
