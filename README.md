# Exchange Online Policy Consolidation Scripts

This toolkit provides PowerShell scripts to export all inbound security policies from Exchange Online into a consolidated CSV for review and management.

## Overview

The toolkit includes three main components:

1. **Export-ExchangePolicies.ps1** - Exports all policies to CSV (requires Exchange Online connection)
2. **Analyze-ExchangePolicies.ps1** - Validates and analyzes the CSV (does NOT require Exchange Online)
3. **Apply-ExchangePolicies.ps1** - Applies decisions made in the CSV back to Exchange Online (requires Exchange Online connection)

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- ExchangeOnlineManagement module installed:
  ```powershell
  Install-Module -Name ExchangeOnlineManagement -Repository PSGallery -Force
  ```
- Global Administrator or Security Administrator access in Microsoft 365

## Script 1: Export-ExchangePolicies.ps1

### Purpose
Collects all inbound security policy data from Exchange Online and exports to a CSV file.

### What It Collects

The script retrieves all allowed/blocked/excluded entries from:

- **Anti-Spam Policies** (HostedContentFilterPolicy)
  - Allowed Senders & Domains
  - Blocked Senders & Domains
  - Excluded Senders & Domains

- **Anti-Phishing Policies** (AntiPhishPolicy)
  - Allowed Senders & Domains
  - Blocked Senders & Domains
  - Excluded Senders, Domains & Sub-Domains

- **Anti-Malware Policies** (MalwareFilterPolicy)
  - Allowed Senders & Domains
  - Excluded Senders & Domains

- **Strict & Standard Preset Policies**
  - Same list types as above policies

- **Default Connection Filter Policy** (HostedConnectionFilterPolicy)
  - Allowed IPs (IP Allow List)
  - Blocked IPs (IP Block List)

### Usage

#### Basic Usage
```powershell
.\Export-ExchangePolicies.ps1
```
This will create a CSV file in the current directory with a timestamp: `Exchange_Policies_20260216_120000.csv`

#### With Custom Output Path
```powershell
.\Export-ExchangePolicies.ps1 -OutputPath "C:\Exports\MyPolicies.csv"
```

#### With Saved Credentials
```powershell
$cred = Get-Credential
.\Export-ExchangePolicies.ps1 -Credential $cred
```

### CSV Output Format

The exported CSV contains the following columns:

| Column | Description | Example |
|--------|-------------|---------|
| Object | The sender address, domain, or IP | `user@example.com`, `example.com`, `192.168.1.0/24` |
| PolicyType | Type of policy | `Anti-Spam`, `Anti-Phishing`, `Anti-Malware`, `Connection Filter` |
| PolicyName | Name of the specific policy | `Default`, `Policy1` |
| ListType | Type of list entry | `AllowedSenders`, `BlockedSenders`, `ExcludedSenders`, `AllowedDomains`, `BlockedDomains`, `ExcludedDomains`, `ExcludedSubDomains`, `AllowedIPs`, `BlockedIPs` |
| TABL | Tenant Allow/Block List action (leave blank or enter: `Allow` / `Block`) | |
| MailFlowRule | Mail flow rule action (leave blank or enter: `Create`) | |
| DefaultConnFilter | Connection filter action (leave blank or enter: `Add`) | |
| Remove | Remove from current policy (leave blank or enter: `Yes`) | |

### How to Use the CSV

1. Open the exported CSV in Excel or your preferred spreadsheet application
2. Review each object and its source
3. For each row, decide on ONE action:
   - **TABL**: Add to Tenant Allow/Block List (enter `Allow` or `Block`)
   - **MailFlowRule**: Create Exchange mail flow rule (enter `Create`)
   - **DefaultConnFilter**: Add to default connection filter (enter `Add`)
   - **Remove**: Remove from current policy (enter `Yes`)
4. Leave action columns blank if no action needed
5. Save the CSV

### Example CSV Rows

```
Object,PolicyType,PolicyName,ListType,TABL,MailFlowRule,DefaultConnFilter,Remove
partner@trusted.com,Anti-Spam,Default,AllowedSenders,Allow,,, 
spam.domain.com,Anti-Spam,Policy1,BlockedDomains,,Create,, 
192.168.1.100,Connection Filter,Default,AllowedIPs,,, ,
malware.site.net,Anti-Malware,Default,BlockedDomains,Block,,,
```

## Script 2: Analyze-ExchangePolicies.ps1

### Purpose
Validates CSV integrity, provides analysis and statistics, and helps identify duplicates across policies. **This script does not require an Exchange Online connection.**

### When to Use
Run this script after exporting policies and before applying changes:
1. Validate the exported CSV data
2. Review summary statistics and policy breakdown
3. Identify duplicate objects across policies
4. Filter data by policy type, list type, or object pattern
5. Export results by action type for focused review

### Usage

#### Validate CSV for Errors
Checks for invalid action values and highlights issues:
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Validate
```

#### Show Summary Statistics
Displays breakdown by policy type and list type:
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Summary
```

#### Find Duplicate Objects
Identifies objects appearing in multiple policies:
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action FindDuplicates
```

#### Filter by Policy Type
Shows entries from a specific policy type:
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action FilterByType -PolicyType "Anti-Spam"
```

#### Filter by List Type
Shows entries from a specific list type:
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action FilterByListType -ListType "AllowedSenders"
```

#### Export by Action Type
Creates separate CSV files grouped by action (TABL, Mail Flow Rule, etc.):
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action ExportByAction -OutputPath "C:\Exports"
```

### CSV Data Reference

For detailed information about CSV columns, data types, and list types, see [CSV_DATA_DICTIONARY.md](CSV_DATA_DICTIONARY.md).

## Script 3: Apply-ExchangePolicies.ps1

### Purpose
Reads the updated CSV and applies the marked actions to Exchange Online.

### Usage

#### Preview Mode (Recommended First Step)
Displays what would be done without making changes:
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Preview
```

#### Export Mode (Recommended Second Step)
Generates a PowerShell script that can be reviewed before execution:
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Export -OutputScript "C:\Exports\ApplyChanges.ps1"
```

Then review the generated `ApplyChanges.ps1` script and run it when ready.

#### Apply Mode (With Confirmation)
Applies changes with a confirmation prompt:
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Apply
```

#### Apply Mode (No Confirmation - Caution!)
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Apply -SkipConfirmation
```

## Recommended Workflow

For a complete step-by-step guide to getting started, see [QUICKSTART.md](QUICKSTART.md).

### Phase 1: Export & Review

**Step 1: Export Policies**
```powershell
# Run Export script (requires Exchange Online connection)
.\Export-ExchangePolicies.ps1 -OutputPath "C:\Exports\Exchange_Policies.csv"
```

**Step 2: Initial Analysis** (no connection needed)
```powershell
# Get summary statistics to understand current state
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Summary

# Find duplicates across policies
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action FindDuplicates
```

**Step 3: Review & Plan**
1. Open CSV in Excel or similar application
2. Review each object and its source policy
3. Use the Analyze script with filtering to focus on specific policy types or list types
4. Decide on consolidation strategy (TABL, Mail Flow Rules, Connection Filter, or Remove)
5. Mark your decisions in the appropriate action columns

### Phase 2: Validate & Plan Changes

**Step 4: Validate CSV** (no connection needed)
```powershell
# Check for data entry errors
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Validate

# Export by action type for focused review
.\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action ExportByAction -OutputPath "C:\Exports"
```

**Step 5: Preview Changes** (requires Exchange Online connection)
```powershell
# See what will be applied without making changes
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Preview
```

### Phase 3: Generate & Review Deployment Script

**Step 6: Export Script** (requires Exchange Online connection)
```powershell
# Generate PowerShell script for review
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Export -OutputScript "C:\Exports\ApplyChanges.ps1"
```

**Step 7: Review & Approve**
1. Review the generated `ApplyChanges.ps1` script
2. Share with security team for approval
3. Verify all changes match your plan
4. Check for any manual actions needed (mail flow rules, policy removals)

### Phase 4: Deploy Changes

**Step 8: Apply Changes** (requires Exchange Online connection)
```powershell
# Option A: Run generated script directly
.\ApplyChanges.ps1

# Option B: Use Apply script with confirmation
.\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Apply
```

**Step 9: Verify**
1. Monitor the process output
2. Check Exchange Online admin center for changes
3. Verify TABL entries, mail flow rules, and connection filter updates
4. Test with sample messages to ensure policies work as intended

### Key Points

- **Export & Apply require Exchange Online connection** - Run from an admin machine with ExchangeOnlineManagement module
- **Analyze can run anywhere** - Useful for reviewing and planning without connection
- **Always preview first** - Use Preview mode before applying changes
- **Generate script for approval** - Use Export mode to create reviewable PowerShell script
- **Test incrementally** - Start with TABL entries, verify, then move to other actions

## Important Considerations

### Tenant Allow/Block List (TABL)
- New in Microsoft 365
- Use for permanent allow/block decisions
- Entries can take up to 30 minutes to take effect
- Supports senders and IPs
- Better for long-term policy management

### Exchange Mail Flow Rules (Transport Rules)
- More flexible for complex conditions
- Can include message properties, attachments, etc.
- Requires manual rule creation for now
- Better for conditional blocking

### Default Connection Filter
- Filters at SMTP receive connector level
- IP-based and domain-based filtering
- Legacy approach but still useful
- Takes immediate effect

### Removal from Policies
- Be cautious when removing entries
- Verify impact before removing
- Consider moving to TABL instead of removing

## Troubleshooting

### "Cannot find module ExchangeOnlineManagement"
```powershell
Install-Module -Name ExchangeOnlineManagement -Repository PSGallery -Force
Import-Module ExchangeOnlineManagement
```

### "Invalid operation. The 'ExO V2' module is already loaded..."
Close existing PowerShell window with Exchange Online connection or use:
```powershell
Disconnect-ExchangeOnline -Confirm:$false
```

### "Access Denied" errors
Ensure account has Security Administrator or Global Administrator role:
- Go to https://admin.microsoft.com
- Navigate to Users > Active Users
- Select user and check Roles tab

### Script hangs during connection
- Verify internet connectivity
- Try closing and reopening PowerShell
- Run in PowerShell 7+ if possible

## CSV Best Practices

1. **Backup Original**: Keep the original export before editing
2. **Use Filters**: Use spreadsheet app filters to review by PolicyType or ListType
3. **Batch Actions**: Group similar objects for bulk review
4. **Color Code**: Use conditional formatting to highlight actions
5. **Comments**: Add notes in a new column for context
6. **Limits**: Consider TABL size limits (check Microsoft documentation)

## Additional Resources

- [Tenant Allow/Block List](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/allow-block-list?view=o365-worldwide)
- [Mail Flow Rules in Exchange Online](https://learn.microsoft.com/en-us/exchange/security-and-compliance/mail-flow-rules/mail-flow-rules)
- [Connection Filter Policies](https://learn.microsoft.com/en-us/powershell/module/exchange/Set-HostedConnectionFilterPolicy)
- [Hosted Content Filter Policies](https://learn.microsoft.com/en-us/powershell/module/exchange/Set-HostedContentFilterPolicy)

## Support

If you encounter issues:
1. Check the logs in PowerShell output
2. Verify your permissions and connectivity
3. Ensure modules are up to date: `Update-Module ExchangeOnlineManagement`
4. Try running in PowerShell 7+ (cross-platform)

## Version History

- v1.0 (2026-02-16): Initial release
  - Export of anti-spam, anti-phish, anti-malware, and connection filter policies
  - Preview, Export, and Apply modes for changes
  - Comprehensive CSV output with action columns

## License

These scripts are provided as-is for managing Exchange Online policies.

## Disclaimer

Always test in a non-production environment first. These scripts modify security policies and should be reviewed carefully before production use. Ensure proper backups and approvals are in place.
