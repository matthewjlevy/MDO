# v1.1 Documentation & Code Updates Summary

**Date:** February 16, 2026  
**Version:** 1.1 Release

## Overview
Complete documentation updates reflecting the latest features and bug fixes implemented since v1.0 release.

---

## Major Features Added

### ✅ Rollback Capability
- **Status**: Fully implemented and tested
- **Location**: All generated ApplyChanges scripts
- **Usage**: 
  ```powershell
  # Apply changes
  .\ApplyChanges.ps1
  
  # Rollback if needed
  .\ApplyChanges.ps1 -Rollback
  ```
- **Coverage**:
  - TABL entries (both Allow and Block)
  - Connection Filter IP lists
  - Handles edge cases gracefully
  - Manual TODO items (Mail Flow Rules, Policy Removals) require manual rollback

### 📋 Sample CSV File
- **File**: SAMPLE_Exchange_Policies.csv
- **Content**: 34 realistic example rows
- **Coverage**: All policy types and list types
- **Purpose**: Help users understand CSV format before running export

---

## Bug Fixes

### 🔧 Cmdlet Syntax Corrections
**Files Affected**: Apply-ExchangePolicies.ps1

**Issues Fixed**:
1. **New-TenantAllowBlockListItems**
   - ❌ Was: `-ListType allow/block` (invalid)
   - ✅ Now: `-Allow` / `-Block` (switch parameters)
   - ❌ Was: `-EntryType Sender/IP` (invalid)
   - ✅ Now: `-ListType Sender` / `-ListType IP`

2. **Set-HostedConnectionFilterPolicy**
   - ❌ Was: Attempting to set `-AllowedSenderDomains` (invalid)
   - ✅ Now: Only uses `-IPAllowList` / `-IPBlockList`
   - Added warnings when non-IP entries marked for Connection Filter

3. **Variable Naming Conflict**
   - ❌ Was: `$action` variable conflicted with `$Action` parameter
   - ✅ Now: Renamed to `$tablAction` throughout

### 🧹 Parser Error Fixes (Analyze-ExchangePolicies.ps1)
- Fixed help documentation format
- Updated multi-line parameter descriptions
- Fixed variable reference syntax with `${rowNum}` delimiters

---

## Documentation Updates

### README.md
**Additions**:
- ✅ New "Rollback Feature" section with:
  - How to use rollback
  - What gets rolled back automatically
  - Example output
  - Use cases

- ✅ Enhanced workflow with Step 10:
  - Optional rollback after testing
  - Guidance on when to rollback

- ✅ Visual CSV Preview:
  - Color-coded example table
  - Excel tips for filtering and formatting
  - Sample file reference

- ✅ Updated Key Points:
  - Added note about rollback availability
  - Clarified connection requirements

- ✅ Updated Version History:
  - v1.1 entry with new features
  - v1.0 entry preserved

### CHANGELOG.md
**Comprehensive Updates**:
- ✅ New v1.1 section with:
  - All added features
  - All bug fixes
  - Technical improvements
  - Enhanced error handling

- ✅ Updated future roadmap:
  - Renamed to v1.2 and beyond
  - Added realistic timelines

- ✅ Fixed issues section:
  - Lists all issues resolved in v1.1
  - Lists all issues resolved in v1.0

- ✅ Installation history table

- ✅ Updated statistics:
  - Increased code lines: 1,100+ → 1,150+
  - Added sample files count

### CSV_DATA_DICTIONARY.md
**Enhanced Data Reference**:
- ✅ PolicyType expanded:
  - Added 3 Preset policy types
  - Clarified difference between regular and preset
  - Noted Microsoft-managed prefixes

- ✅ ListType expanded:
  - Added `ExcludedSenders`
  - Added `ExcludedDomains`
  - Added `ExcludedSubDomains`
  - Added explanation of Excluded vs Allowed vs Blocked

- ✅ Updated mapping table:
  - Shows all 7 policy types (regular + preset)
  - Shows all 9 list types
  - Clear indication of what each policy supports

- ✅ Added context:
  - Explanation of preset policies
  - Anti-Phishing specific ExcludedSubDomains note

### QUICKSTART.md
**Updated Get Started Guide**:
- ✅ New Scenario 3b: "Safe Testing with Rollback"
  - Apply → Test → Rollback workflow
  - Shows how to use rollback parameter

- ✅ Updated Scenario 3:
  - Added rollback example
  - Shows command syntax

- ✅ Enhanced safety section:
  - Added rollback capability to "Is My Data Safe?"
  - Reassures users about reversibility

---

## Testing & Validation

### ✅ Tested Features
- [x] Rollback of TABL Allow entries
- [x] Rollback of TABL Block entries
- [x] Rollback of Connection Filter IP Allow entries
- [x] Rollback of Connection Filter IP Block entries
- [x] Handling of already-removed entries
- [x] Query performance with realistic datasets (417 entries)

### ✅ Verified Cmdlet Syntax
- [x] New-TenantAllowBlockListItems with correct parameters
- [x] Remove-TenantAllowBlockListItems with ListType parameter
- [x] Set-HostedConnectionFilterPolicy with IP lists
- [x] Get-TenantAllowBlockListItems for lookup

### ✅ Documentation Accuracy
- [x] All examples tested and working
- [x] All path references valid
- [x] All parameter names correct
- [x] All output examples accurate

---

## Files Modified

| File | Status | Changes |
|------|--------|---------|
| Apply-ExchangePolicies.ps1 | ✅ Modified | Rollback feature, syntax fixes, variable names |
| Analyze-ExchangePolicies.ps1 | ✅ Modified | Parser error fixes, help documentation |
| README.md | ✅ Modified | Rollback section, updated workflow, visual examples |
| CHANGELOG.md | ✅ Modified | v1.1 release notes, updated roadmap |
| CSV_DATA_DICTIONARY.md | ✅ Modified | Preset policies, Excluded* list types |
| QUICKSTART.md | ✅ Modified | Rollback scenarios, safety notes |
| SAMPLE_Exchange_Policies.csv | ✅ Created | 34 realistic example rows |

---

## Compatibility

### PowerShell Versions
- ✅ PowerShell 5.1 (Windows)
- ✅ PowerShell 7.x (Windows/Linux/macOS)

### Exchange Online Module
- ✅ ExchangeOnlineManagement v3.0+

### Operating Systems
- ✅ Windows
- ✅ macOS (with module)
- ✅ Linux (with module)

---

## Known Limitations (Unchanged from v1.0)

- Mail Flow Rule creation requires manual action (TODO comments in scripts)
- Policy removal from Anti-Spam/Anti-Phishing requires manual action (TODO comments)
- TABL entries cannot contain wildcards (Exchange Online limitation)
- TABL has size limits (per Microsoft documentation)
- Changes take 30-60 minutes to replicate globally
- Rollback cannot undo manual TODO items

---

## Next Steps for Users

1. **Review the CHANGELOG** to understand all changes
2. **Check the Rollback examples** in README.md
3. **Test with SAMPLE_Exchange_Policies.csv** to understand format
4. **Try Export script** to see real data
5. **Use Preview mode** before applying any changes
6. **Leverage Rollback** for safe testing

---

## Version Information

- **Current Version**: 1.1
- **Release Date**: February 16, 2026
- **Previous Version**: 1.0 (same date)
- **Total Code Lines**: 1,150+
- **Documentation Pages**: 5 (README, QUICKSTART, CSV_DATA_DICTIONARY, CHANGELOG, UPDATES_SUMMARY)
- **Sample Files**: 1 (SAMPLE_Exchange_Policies.csv)

---

## Quick Links

- 📖 [README.md](README.md) - Full documentation
- ⚡ [QUICKSTART.md](QUICKSTART.md) - 5-minute quick start
- 📊 [CSV_DATA_DICTIONARY.md](CSV_DATA_DICTIONARY.md) - Data format reference
- 📋 [CHANGELOG.md](CHANGELOG.md) - Complete version history
- 📄 [SAMPLE_Exchange_Policies.csv](SAMPLE_Exchange_Policies.csv) - Example data

---

**End of v1.1 Updates Summary**
