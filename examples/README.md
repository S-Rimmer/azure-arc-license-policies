# Example assignment parameter files

Ready-to-use Azure Policy **assignment** parameter files for the Arc license policies.
Pass one to `scripts/New-Assignment.ps1` with `-PolicyParameterFile`, or to
`az policy assignment create --params @<file>`.

## SQL Server license type

| File | Effect | Scope of change | Use when |
|------|--------|-----------------|----------|
| `sql-license-type.audit.parameters.json` | `AuditIfNotExists` | none (report only) | First pass. See which SQL instances are non-compliant without changing anything. |
| `sql-license-type.enforce-unspecified.parameters.json` | `DeployIfNotExists` | only instances with **no** license type set | Safe enforcement. Fills in unset instances and leaves already-set `Paid` / `PAYG` / `LicenseOnly` (Server+CAL) untouched. |

Both set `targetLicenseType = Paid`. Change it to `PAYG` if you bill hourly.
`licenseTypesToOverwrite` is limited to `["Unspecified"]` so existing, intentional values
are never overwritten.

### Audit first (no roles required)

```powershell
./scripts/New-Assignment.ps1 -SubscriptionId "<sub>" `
  -PolicyName "configure-arc-sql-license-type" -Location "eastus" `
  -PolicyParameterFile ./examples/sql-license-type.audit.parameters.json `
  -SkipRoleAssignment
```

### Enforce (unset instances only)

```powershell
./scripts/New-Assignment.ps1 -SubscriptionId "<sub>" `
  -PolicyName "configure-arc-sql-license-type" -Location "eastus" `
  -PolicyParameterFile ./examples/sql-license-type.enforce-unspecified.parameters.json

./scripts/Start-Remediation.ps1 -SubscriptionId "<sub>" `
  -AssignmentName "configure-arc-sql-license-type"
```

> `Paid` asserts the instance is covered by Software Assurance or a subscription license.
> Align the license type with actual entitlement before enforcing.
