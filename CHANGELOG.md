# Changelog

All notable changes to the Exchange Online Policy Consolidation Toolkit will be documented in this file.

## [1.2] - 2026-02-18

### Added
- **Analyze-TABL.ps1**
  - Exports TABL entries for Sender, Url, FileHash, and IP list types
  - Cross-references TABL values against the consolidated policy CSV
  - Output includes TABL metadata plus policy name matches

### Documentation
- Added optional Analyze-TABL usage to README.md
- Added optional TABL analysis step to QUICKSTART.md

## [1.1] - 2026-02-16

### Added
- **Rollback Feature in Apply-ExchangePolicies.ps1**
  - Generated scripts now support `-Rollback` parameter
  - Same script can both apply AND rollback changes
  - Automatic rollback for TABL entries using Get/Remove-TenantAllowBlockListItems
  - Automatic rollback for Connection Filter using Set-HostedConnectionFilterPolicy
  - User-friendly confirmation messages showing rollback progress
  - Safety warnings for entries that may have been already removed

- **Sample CSV File**
  - SAMPLE_Exchange_Policies.csv with realistic example data
  - Demonstrates all policy types and list types
  - Shows various action options (Allow, Block, Add)
  - Useful for understanding expected format before running export

- **Enhanced Documentation**
  - Visual CSV preview in README.md showing Excel representation
  - Color-coded legend for action values
  - Excel tips for filtering, sorting, and formatting
  - Reference to sample CSV file

### Fixed
- **Cmdlet Syntax Corrections in Apply-ExchangePolicies.ps1**
  - New-TenantAllowBlockListItems now uses `-Allow` / `-Block` (switch parameters) instead of `-ListType allow/block`
  - New-TenantAllowBlockListItems now uses `-ListType Sender` or `-ListType IP` instead of `-EntryType`
  - Rollback now includes `-ListType` parameter in Remove-TenantAllowBlockListItems
  - Connection Filter now properly handles IP-only restrictions (does not attempt domain operations)
  - Added helpful notes when non-IP entries marked for Connection Filter

- **Variable Naming Conflict**
  - Renamed PowerShell variable from `$action` to `$tablAction` to avoid conflict with `$Action` parameter
  - Resolves parameter validation error when generating scripts

- **Parser Errors in Analyze-ExchangePolicies.ps1**
  - Fixed help documentation parameter descriptions
  - Updated parameter documentation to use multi-line format for readability
  - Fixed variable reference syntax using `${rowNum}` delimiters

- **Script Syntax Issues**
  - Corrected `ApplyChanges.ps1` example template with proper scriptblock syntax

### Enhanced
- **Error Handling**
  - More descriptive error messages for TABL failures
  - Better handling of missing or already-removed entries during rollback
  - Improved Connection Filter parameter validation

- **User Experience**
  - Generated scripts now display mode (APPLY MODE / ROLLBACK MODE) clearly
  - Success indicators (✓) for completed operations
  - Better progress reporting during rollback
  - Helpful command reminders in script output

- **Testing & Validation**
  - Verified TABL operations work correctly with actual Exchange Online
  - Validated rollback operations don't fail on already-removed entries
  - Tested with realistic policy data

### Technical Details
- Scripts now properly handle both apply and rollback scenarios
- Generated scripts are idempotent for TABL and Connection Filter operations
- Rollback safely handles edge cases (missing entries, connection failures)
- All scripts tested with PowerShell 5.1 and PowerShell 7.x

## [1.0] - 2026-02-16

### Added
- **Export-ExchangePolicies.ps1**: Main script to export all inbound security policies
  - Exports Anti-Spam policies (HostedContentFilterPolicy) with Excluded senders/domains
  - Exports Anti-Phishing policies (AntiPhishPolicy) with Excluded senders/domains/subdomains
  - Exports Anti-Malware policies (MalwareFilterPolicy) with Excluded senders/domains
  - Strict and Standard Preset Security Policies (all policy types)
  - Exports Default Connection Filter policy (HostedConnectionFilterPolicy)
  - Creates consolidated CSV with source information
  - Handles null/empty values gracefully
  - Supports custom output paths and credentials
  - Deduplication across policy sources

- **Apply-ExchangePolicies.ps1**: Script to apply decisions to Exchange Online
  - Preview mode: See what changes would be made
  - Export mode: Generate PowerShell script for review
  - Apply mode: Execute changes with confirmation
  - Skip confirmation option for automated deployments
  - Support for TABL operations
  - Support for Connection Filter modifications
  - Comprehensive error handling and logging

- **Analyze-ExchangePolicies.ps1**: Utility script for CSV analysis
  - Summary statistics and counts
  - Validation of CSV format and values
  - Filter by policy type, list type, or object pattern
  - Duplicate detection
  - Export by action type (separate CSVs)
  - Actionable warnings and error messages

- **Documentation**
  - README.md: Comprehensive user guide (7,000+ words)
  - QUICKSTART.md: 5-minute quick start guide
  - CSV_DATA_DICTIONARY.md: Data format reference
  - CHANGELOG.md: This file

### Features
- **Safety First**
  - No modification happens without explicit user action
  - Preview mode for safe operation simulation
  - Export mode for script review before execution
  - Confirmation prompts in Apply mode
  - Complete error handling and recovery

- **TABL Support**
  - Add entries to Tenant Allow/Block List
  - Support for both Allow and Block actions
  - Proper entry type detection (sender vs IP)

- **Connection Filter Support**
  - Modify IP Allow/Block lists
  - Automatic IP vs domain detection

- **CSV Consolidation**
  - Deduplication of entries across policies
  - Organized output with sortable columns
  - Multiple action options per object
  - Complete policy source information
  - Support for Excluded* properties (ExcludedSenders, ExcludedDomains, ExcludedSubDomains)
  - Distinction between regular and Preset policies

- **Flexibility**
  - Support for custom credentials
  - Customizable output paths
  - Filter capabilities in analysis script
  - Multiple operation modes

### Technical Details
- Uses ExchangeOnlineManagement module (v3.0+)
- Compatible with PowerShell 5.1 and later
- PowerShell 7+ recommended for best performance
- Windows, macOS, and Linux support (with module)
- UTF-8 CSV encoding for international support
- Handles large datasets efficiently

### Known Limitations
- Mail Flow Rule creation requires manual action (shows TODO)
- Policy removal from Anti-Spam/Anti-Phishing shows TODO
- TABL entries cannot contain wildcards
- TABL has size limits (per Microsoft documentation)
- Applied changes take 30-60 minutes to replicate globally

### Files Included
- `Export-ExchangePolicies.ps1` - 350+ lines
- `Apply-ExchangePolicies.ps1` - 400+ lines
- `Analyze-ExchangePolicies.ps1` - 350+ lines
- `README.md` - Comprehensive documentation
- `QUICKSTART.md` - Quick start guide
- `CSV_DATA_DICTIONARY.md` - Data format reference
- `CHANGELOG.md` - Version history

## Future Roadmap

### Planned Features (v1.2)
- [ ] Mail Flow Rule creation automation
- [ ] Policy removal automation for Anti-Spam/Anti-Phishing
- [ ] JSON export option for API integration
- [ ] HTML report generation
- [ ] Change batching for bulk operations

### Potential v1.3 Features
- [ ] Integration with Microsoft Defender for Office 365
- [ ] Advanced threat analytics integration
- [ ] Policy compliance checking
- [ ] Automated recommendations engine
- [ ] Multi-tenant support
- [ ] Azure Automation runbook support

### Potential v2.0 Features
- [ ] Web UI dashboard
- [ ] Audit trail and logging
- [ ] Change approval workflow
- [ ] Scheduled policy exports
- [ ] Policy comparison and diff tools
- [ ] Policy templating system

## Installation History

| Version | Date | Status |
|---------|------|--------|
| 1.1 | 2026-02-16 | Released ✓ |
| 1.0 | 2026-02-16 | Released ✓ |

## Migration Guide

### From Earlier Manual Processes
If you were previously managing policies manually:

1. **Export current state**: Run Export script first
2. **Analyze differences**: Use Analyze script to understand current setup
3. **Plan migration**: Use CSV to plan consolidation
4. **Test changes**: Use Preview and Export modes
5. **Apply gradually**: Consider applying changes to test policies first

## Support & Issues

### Common Issues Fixed in 1.1
- ✓ Fixed cmdlet parameter syntax for TABL operations
- ✓ Added rollback capability for testing workflows
- ✓ Fixed parser errors in documentation blocks
- ✓ Resolved variable naming conflicts

### Common Issues Fixed in 1.0
- ✓ Handled null values in policy lists
- ✓ Managed duplicate detection across policies
- ✓ Proper credential handling for automation
- ✓ Connection timeout handling
- ✓ CSV UTF-8 encoding for international characters

### Reporting Bugs
When reporting issues, include:
- PowerShell version: `$PSVersionTable.PSVersion`
- Module version: `(Get-Module ExchangeOnlineManagement).Version`
- Error message and stack trace
- Steps to reproduce
- Output of script with `-Verbose` flag if applicable

## Contributing

Suggestions for improvements welcome! Consider:
- Performance optimizations
- Additional analysis features
- Enhanced reporting
- Automation capabilities
- Documentation improvements

## License

This toolkit is provided as-is for managing Exchange Online policies.

## Disclaimer

- Always test in non-production environment first
- Ensure proper approvals before production deployment
- Changes to security policies are irreversible without manual intervention
- Verify changes in Exchange Online admin center after deployment
- Keep backups of exported CSVs for audit trail

---

## Statistics (v1.1)

- **Total Lines of Code**: 1,150+
- **Documentation Pages**: 4 (README, QUICKSTART, Data Dictionary, Changelog)
- **PowerShell Scripts**: 3
- **Supported Policy Types**: 4 (+ Preset variants)
- **Action Types**: 8
- **List Types**: 9
- **Operation Modes**: 3 (Preview, Export, Apply) + Rollback
- **Sample Files**: 1 (SAMPLE_Exchange_Policies.csv)

## Credits

Developed as a comprehensive solution for consolidating Microsoft Exchange Online security policies with rollback capability.

**GitHub Repository:** [Overwatch Scripts - MDO](https://github.com/mlevy/Overwatch-Scripts)

### Added
- **Export-ExchangePolicies.ps1**: Main script to export all inbound security policies
  - Exports Anti-Spam policies (HostedContentFilterPolicy) with Excluded senders/domains
  - Exports Anti-Phishing policies (AntiPhishPolicy) with Excluded senders/domains/subdomains
  - Exports Anti-Malware policies (MalwareFilterPolicy) with Excluded senders/domains
  - Strict and Standard Preset Security Policies (all policy types)
  - Exports Default Connection Filter policy (HostedConnectionFilterPolicy)
  - Creates consolidated CSV with source information
  - Handles null/empty values gracefully
  - Supports custom output paths and credentials
  - Deduplication across policy sources

- **Apply-ExchangePolicies.ps1**: Script to apply decisions to Exchange Online
  - Preview mode: See what changes would be made
  - Export mode: Generate PowerShell script for review
  - Apply mode: Execute changes with confirmation
  - Skip confirmation option for automated deployments
  - Support for TABL operations
  - Support for Connection Filter modifications
  - Comprehensive error handling and logging

- **Analyze-ExchangePolicies.ps1**: Utility script for CSV analysis
  - Summary statistics and counts
  - Validation of CSV format and values
  - Filter by policy type, list type, or object pattern
  - Duplicate detection
  - Export by action type (separate CSVs)
  - Actionable warnings and error messages

- **Documentation**
  - README.md: Comprehensive user guide (7,000+ words)
  - QUICKSTART.md: 5-minute quick start guide
  - CSV_DATA_DICTIONARY.md: Data format reference
  - CHANGELOG.md: This file

### Features
- **Safety First**
  - No modification happens without explicit user action
  - Preview mode for safe operation simulation
  - Export mode for script review before execution
  - Confirmation prompts in Apply mode
  - Complete error handling and recovery

- **TABL Support**
  - Add entries to Tenant Allow/Block List
  - Support for both Allow and Block actions
  - Proper entry type detection (sender vs IP)

- **Connection Filter Support**
  - Modify IP Allow/Block lists
  - Automatic IP vs domain detection

- **CSV Consolidation**
  - Deduplication of entries across policies
  - Organized output with sortable columns
  - Multiple action options per object
  - Complete policy source information
  - Support for Excluded* properties (ExcludedSenders, ExcludedDomains, ExcludedSubDomains)
  - Distinction between regular and Preset policies

- **Flexibility**
  - Support for custom credentials
  - Customizable output paths
  - Filter capabilities in analysis script
  - Multiple operation modes

### Technical Details
- Uses ExchangeOnlineManagement module (v3.0+)
- Compatible with PowerShell 5.1 and later
- PowerShell 7+ recommended for best performance
- Windows, macOS, and Linux support (with module)
- UTF-8 CSV encoding for international support
- Handles large datasets efficiently

### Known Limitations
- Mail Flow Rule creation requires manual action (shows TODO)
- Policy removal from Anti-Spam/Anti-Phishing shows TODO
- TABL entries cannot contain wildcards
- TABL has size limits (per Microsoft documentation)
- Applied changes take 30-60 minutes to replicate globally

### Files Included
- `Export-ExchangePolicies.ps1` - 350+ lines
- `Apply-ExchangePolicies.ps1` - 400+ lines
- `Analyze-ExchangePolicies.ps1` - 350+ lines
- `README.md` - Comprehensive documentation
- `QUICKSTART.md` - Quick start guide
- `CSV_DATA_DICTIONARY.md` - Data format reference
- `CHANGELOG.md` - Version history

## Future Roadmap

### Planned Features (v1.1)
- [ ] Mail Flow Rule creation automation
- [ ] Policy removal automation for Anti-Spam/Anti-Phishing
- [ ] JSON export option for API integration
- [ ] HTML report generation
- [ ] Change batching for bulk operations
- [ ] Rollback/undo capability

### Potential v1.2 Features
- [ ] Integration with Microsoft Defender for Office 365
- [ ] Advanced threat analytics integration
- [ ] Policy compliance checking
- [ ] Automated recommendations engine
- [ ] Multi-tenant support
- [ ] Azure Automation runbook support

### Potential v2.0 Features
- [ ] Web UI dashboard
- [ ] Audit trail and logging
- [ ] Change approval workflow
- [ ] Scheduled policy exports
- [ ] Policy comparison and diff tools
- [ ] Policy templating system

## Installation History

| Version | Date | Status |
|---------|------|--------|
| 1.0 | 2026-02-16 | Released ✓ |

## Migration Guide

### From Earlier Manual Processes
If you were previously managing policies manually:

1. **Export current state**: Run Export script first
2. **Analyze differences**: Use Analyze script to understand current setup
3. **Plan migration**: Use CSV to plan consolidation
4. **Test changes**: Use Preview and Export modes
5. **Apply gradually**: Consider applying changes to test policies first

## Support & Issues

### Common Issues Fixed in 1.0
- ✓ Handled null values in policy lists
- ✓ Managed duplicate detection across policies
- ✓ Proper credential handling for automation
- ✓ Connection timeout handling
- ✓ CSV UTF-8 encoding for international characters

### Reporting Bugs
When reporting issues, include:
- PowerShell version: `$PSVersionTable.PSVersion`
- Module version: `(Get-Module ExchangeOnlineManagement).Version`
- Error message and stack trace
- Steps to reproduce
- Output of script with `-Verbose` flag if applicable

## Contributing

Suggestions for improvements welcome! Consider:
- Performance optimizations
- Additional analysis features
- Enhanced reporting
- Automation capabilities
- Documentation improvements

## License

This toolkit is provided as-is for managing Exchange Online policies.

## Disclaimer

- Always test in non-production environment first
- Ensure proper approvals before production deployment
- Changes to security policies are irreversible without manual intervention
- Verify changes in Exchange Online admin center after deployment
- Keep backups of exported CSVs for audit trail

---

## Statistics

- **Total Lines of Code**: 1,100+
- **Documentation Pages**: 4 (README, QUICKSTART, Data Dictionary, Changelog)
- **PowerShell Scripts**: 3
- **Supported Policy Types**: 4
- **Action Types**: 8
- **List Types**: 6
- **Operation Modes**: 3 (Preview, Export, Apply)

## Credits

Developed as a comprehensive solution for consolidating Microsoft Exchange Online security policies.

**GitHub Repository:** [Overwatch Scripts - MDO](https://github.com/mlevy/Overwatch-Scripts)

---

Last Updated: 2026-02-16
