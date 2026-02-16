# Quick Start Guide - Exchange Policy Consolidation

## 5-Minute Setup

### Step 1: Install Required Module (First Time Only)
```powershell
Install-Module -Name ExchangeOnlineManagement -Repository PSGallery -Force
```

### Step 2: Export Your Policies
```powershell
cd "C:\Users\mlevy\Repos\Overwatch Scripts\MDO"
.\Export-ExchangePolicies.ps1
```

This creates a CSV file with all your policies. Wait for it to complete (may take 1-2 minutes).

### Step 3: Open and Review the CSV
1. Open the generated CSV file in Excel
2. Review the objects and their sources
3. Make decisions for each row:
   - Enter `Allow` or `Block` in the TABL column to use Tenant Allow/Block List
   - Enter `Create` in MailFlowRule column for complex rules
   - Enter `Add` in DefaultConnFilter for connection-level filtering
   - Enter `Yes` in Remove column to delete from current policy

### Step 4: Save Your CSV Changes

### Step 5: Preview Changes
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "PATH_TO_YOUR_CSV.csv" -Action Preview
```

This shows what would happen without making changes.

### Step 6: Apply Changes (When Ready)
```powershell
.\Apply-ExchangePolicies.ps1 -CSVPath "PATH_TO_YOUR_CSV.csv" -Action Apply
```

## Common Scenarios

### Scenario 1: Consolidate All Lists to TABL
```powershell
# Preview first
.\Apply-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action Preview

# For each row, set TABL to "Allow" or "Block" based on ListType
# Then apply
.\Apply-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action Apply
```

### Scenario 2: Analyze What You Have
```powershell
# See summary statistics
.\Analyze-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action Summary

# Find duplicates across policies
.\Analyze-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action FindDuplicates

# Look at only Anti-Spam policies
.\Analyze-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action FilterByType -PolicyType "Anti-Spam"
```

### Scenario 3: Review Before Applying
```powershell
# Generate a PowerShell script you can review
.\Apply-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action Export -OutputScript "C:\temp\changes.ps1"

# Open and review C:\temp\changes.ps1 in your editor

# When satisfied, run it
powershell -File "C:\temp\changes.ps1"
```

### Scenario 4: Validate Your CSV Before Applying
```powershell
.\Analyze-ExchangePolicies.ps1 -CSVPath "exchange_policies.csv" -Action Validate
```

## Troubleshooting Quick Reference

| Problem | Solution |
|---------|----------|
| "Cannot find module ExchangeOnlineManagement" | Run: `Install-Module -Name ExchangeOnlineManagement -Repository PSGallery -Force` |
| "Access Denied" | Make sure your account is Global Admin or Security Admin |
| Script hangs during connection | Close PowerShell and try again, or use PowerShell 7+ |
| "ExO V2 module is already loaded" | Run: `Disconnect-ExchangeOnline -Confirm:$false` |

## File Summary

| Script | Purpose |
|--------|---------|
| Export-ExchangePolicies.ps1 | Exports all policies to CSV |
| Apply-ExchangePolicies.ps1 | Applies decisions to Exchange Online |
| Analyze-ExchangePolicies.ps1 | Analyzes and validates CSV data |
| README.md | Full documentation |
| QUICKSTART.md | This file |

## Sample CSV Decision Matrix

| Object Example | ListType | Decision | TABL | Action |
|---|---|---|---|---|
| partner@trusted.com | AllowedSenders | Approve permanently | Allow | ✓ |
| spam.net | BlockedDomains | Centralize | Block | ✓ |
| trusted.partner.net | AllowedDomains | Use TABL instead | Allow | ✓ |
| 192.168.1.1/32 | AllowedIPs | Keep in conn filter | | Keep original |
| badactor@malware.site | BlockedSenders | Remove after review | | Yes |

## Is My Data Safe?

- ✓ Export script is **READ-ONLY** - doesn't make any changes
- ✓ Preview mode shows changes without applying them
- ✓ Export mode generates script for review before running
- ✓ Apply mode asks for confirmation before making changes
- ✓ All changes are reversible

## Need Help?

1. Check README.md for detailed documentation
2. Run scripts with `-?` for parameters: `.\Export-ExchangePolicies.ps1 -?`
3. Use Preview mode first to understand what will happen
4. Start with test/non-critical policies

## Performance Notes

- Export typically takes 1-2 minutes depending on policy count
- Large organizations may need 5+ minutes
- Apply operations process items sequentially
- Check email during script execution - it's safe

## Next Steps

1. [x] Install module
2. [x] Run Export script
3. [x] Review and decide on CSV actions
4. [x] Use Analyze script to validate
5. [x] Use Preview or Export mode
6. [x] Apply changes
7. [x] Verify in Exchange admin center

Good luck! 🚀
