#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Validates and analyzes the consolidated policy CSV file.

.DESCRIPTION
    This script provides utilities for working with the consolidated policy CSV:
    - Validates action column entries
    - Shows statistics and summaries
    - Filters data by policy type, list type, or object pattern
    - Helps identify duplicates or overlapping entries

.PARAMETER CSVPath
    Path to the consolidated policy CSV file.

.PARAMETER Action
    Action to perform:
    - Validate: Check for invalid entries in action columns
    - Summary: Show statistics and summary information
    - FilterByType: Show entries filtered by policy type
    - FilterByListType: Show entries filtered by list type
    - FindDuplicates: Find potential duplicate entries
    - ExportByAction: Export rows by action type to separate CSVs

.PARAMETER PolicyType
    Filter by policy type. Valid values: Anti-Spam, Anti-Phishing, Anti-Malware, Connection Filter,
    Anti-Spam (Preset), Anti-Phishing (Preset), Anti-Malware (Preset)

.PARAMETER ListType
    Filter by list type. Valid values: AllowedSenders, BlockedSenders, ExcludedSenders,
    AllowedDomains, BlockedDomains, ExcludedDomains, ExcludedSubDomains, AllowedIPs, BlockedIPs

.PARAMETER ObjectPattern
    Filter by object pattern using regex (e.g., '.*@.*' for email addresses)

.PARAMETER OutputPath
    Base path for output files when exporting.

.EXAMPLE
    .\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action Summary
    
.EXAMPLE
    .\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action FilterByType -PolicyType "Anti-Spam"

.EXAMPLE
    .\Analyze-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies.csv" -Action FindDuplicates
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CSVPath,
    
    [ValidateSet("Validate", "Summary", "FilterByType", "FilterByListType", "FindDuplicates", "ExportByAction")]
    [string]$Action = "Summary",
    
    [string]$PolicyType,
    
    [string]$ListType,
    
    [string]$ObjectPattern,
    
    [string]$OutputPath = (Get-Location)
)

# ========================================
# Functions
# ========================================

function Show-Summary {
    param([PSObject[]]$Data)
    
    Write-Host "`n========== SUMMARY ==========" -ForegroundColor Cyan
    Write-Host "Total entries: $($Data.Count)" -ForegroundColor White
    
    $policyTypeCounts = $Data | Group-Object -Property PolicyType | Sort-Object -Property Name
    Write-Host "`nBy Policy Type:" -ForegroundColor Yellow
    foreach ($group in $policyTypeCounts) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Gray
    }
    
    $listTypeCounts = $Data | Group-Object -Property ListType | Sort-Object -Property Name
    Write-Host "`nBy List Type:" -ForegroundColor Yellow
    foreach ($group in $listTypeCounts) {
        Write-Host "  $($group.Name): $($group.Count)" -ForegroundColor Gray
    }
    
    $tabolCount = @($Data | Where-Object {$_.TABL -and $_.TABL -ne ""}).Count
    $mfrCount = @($Data | Where-Object {$_.MailFlowRule -and $_.MailFlowRule -ne ""}).Count
    $dcfCount = @($Data | Where-Object {$_.DefaultConnFilter -and $_.DefaultConnFilter -ne ""}).Count
    $removeCount = @($Data | Where-Object {$_.Remove -and $_.Remove -ne ""}).Count
    
    Write-Host "`nActions Marked:" -ForegroundColor Yellow
    Write-Host "  TABL: $tabolCount" -ForegroundColor Gray
    Write-Host "  Mail Flow Rule: $mfrCount" -ForegroundColor Gray
    Write-Host "  Default Conn Filter: $dcfCount" -ForegroundColor Gray
    Write-Host "  Remove: $removeCount" -ForegroundColor Gray
    
    $noActions = @($Data | Where-Object {
        ($_.TABL -eq "" -or $_.TABL -eq $null) -and 
        ($_.MailFlowRule -eq "" -or $_.MailFlowRule -eq $null) -and 
        ($_.DefaultConnFilter -eq "" -or $_.DefaultConnFilter -eq $null) -and 
        ($_.Remove -eq "" -or $_.Remove -eq $null)
    }).Count
    
    Write-Host "  No action marked: $noActions" -ForegroundColor Gray
    
    Write-Host "`n========== UNIQUE POLICY NAMES ==========" -ForegroundColor Cyan
    $uniquePolicies = $Data | Select-Object -Property PolicyName -Unique | Sort-Object -Property PolicyName
    foreach ($policy in $uniquePolicies) {
        Write-Host "  $($policy.PolicyName)" -ForegroundColor Gray
    }
}

function Validate-CSV {
    param([PSObject[]]$Data)
    
    Write-Host "`n========== VALIDATION RESULTS ==========" -ForegroundColor Cyan
    
    $errors = @()
    $warnings = @()
    
    # Check for invalid action values
    $validActions = @("", "Allow", "Block", "Create", "Add", "Yes", "No")
    
    foreach ($row in $Data) {
        $rowNum = $Data.IndexOf($row) + 2  # +2 for header and 1-based indexing
        
        if ($row.TABL -and $row.TABL -notin $validActions) {
            $errors += "Row ${rowNum}: Invalid TABL value: '$($row.TABL)'. Valid values: Allow, Block"
        }
        
        if ($row.MailFlowRule -and $row.MailFlowRule -notin @("", "Create")) {
            $errors += "Row ${rowNum}: Invalid MailFlowRule value: '$($row.MailFlowRule)'. Valid values: Create"
        }
        
        if ($row.DefaultConnFilter -and $row.DefaultConnFilter -notin @("", "Add")) {
            $errors += "Row ${rowNum}: Invalid DefaultConnFilter value: '$($row.DefaultConnFilter)'. Valid values: Add"
        }
        
        if ($row.Remove -and $row.Remove -notin @("", "Yes", "No")) {
            $errors += "Row ${rowNum}: Invalid Remove value: '$($row.Remove)'. Valid values: Yes"
        }
        
        # Check for multiple actions on same row
        $actions = 0
        if ($row.TABL -and $row.TABL -ne "") { $actions++ }
        if ($row.MailFlowRule -and $row.MailFlowRule -ne "") { $actions++ }
        if ($row.DefaultConnFilter -and $row.DefaultConnFilter -ne "") { $actions++ }
        if ($row.Remove -eq "Yes") { $actions++ }
        
        if ($actions -gt 1) {
            $warnings += "Row ${rowNum}: Multiple actions marked for '$($row.Object)'. Only one should be selected."
        }
        
        # Check for empty objects
        if ([string]::IsNullOrWhiteSpace($row.Object)) {
            $errors += "Row ${rowNum}: Object field is empty."
        }
    }
    
    if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "✓ CSV validation passed! No errors found." -ForegroundColor Green
    } else {
        if ($errors.Count -gt 0) {
            Write-Host "`nErrors ($($errors.Count)):" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "  ✗ $error" -ForegroundColor Red
            }
        }
        
        if ($warnings.Count -gt 0) {
            Write-Host "`nWarnings ($($warnings.Count)):" -ForegroundColor Yellow
            foreach ($warning in $warnings) {
                Write-Host "  ⚠ $warning" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
}

function Find-Duplicates {
    param([PSObject[]]$Data)
    
    Write-Host "`n========== DUPLICATE ANALYSIS ==========" -ForegroundColor Cyan
    
    $objectGroups = $Data | Group-Object -Property Object
    $duplicates = @($objectGroups | Where-Object {$_.Count -gt 1})
    
    if ($duplicates.Count -eq 0) {
        Write-Host "✓ No duplicate objects found." -ForegroundColor Green
        return
    }
    
    Write-Host "Found $($duplicates.Count) objects appearing multiple times:`n" -ForegroundColor Yellow
    
    foreach ($group in $duplicates) {
        Write-Host "→ $($group.Name) [appears $($group.Count) times]" -ForegroundColor White
        
        foreach ($item in $group.Group) {
            Write-Host "    - $($item.PolicyType) / $($item.PolicyName) / $($item.ListType)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

function Export-ByAction {
    param(
        [PSObject[]]$Data,
        [string]$OutputPath
    )
    
    Write-Host "`n========== EXPORTING BY ACTION ==========" -ForegroundColor Cyan
    
    $baseFileName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $CSVPath -Leaf))
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Items with TABL action
    $tablItems = @($Data | Where-Object {$_.TABL -and $_.TABL -ne ""})
    if ($tablItems.Count -gt 0) {
        $path = Join-Path $OutputPath "${baseFileName}_TABL_${timestamp}.csv"
        $tablItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host "✓ TABL items ($($tablItems.Count)): $path" -ForegroundColor Green
    }
    
    # Items with Mail Flow Rule action
    $mfrItems = @($Data | Where-Object {$_.MailFlowRule -and $_.MailFlowRule -ne ""})
    if ($mfrItems.Count -gt 0) {
        $path = Join-Path $OutputPath "${baseFileName}_MailFlowRule_${timestamp}.csv"
        $mfrItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host "✓ Mail Flow Rule items ($($mfrItems.Count)): $path" -ForegroundColor Green
    }
    
    # Items with Connection Filter action
    $dcfItems = @($Data | Where-Object {$_.DefaultConnFilter -and $_.DefaultConnFilter -ne ""})
    if ($dcfItems.Count -gt 0) {
        $path = Join-Path $OutputPath "${baseFileName}_ConnFilter_${timestamp}.csv"
        $dcfItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host "✓ Connection Filter items ($($dcfItems.Count)): $path" -ForegroundColor Green
    }
    
    # Items marked for removal
    $removeItems = @($Data | Where-Object {$_.Remove -eq "Yes"})
    if ($removeItems.Count -gt 0) {
        $path = Join-Path $OutputPath "${baseFileName}_Remove_${timestamp}.csv"
        $removeItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host "✓ Remove items ($($removeItems.Count)): $path" -ForegroundColor Green
    }
    
    # Items with no action
    $noActionItems = @($Data | Where-Object {
        ($_.TABL -eq "" -or $_.TABL -eq $null) -and 
        ($_.MailFlowRule -eq "" -or $_.MailFlowRule -eq $null) -and 
        ($_.DefaultConnFilter -eq "" -or $_.DefaultConnFilter -eq $null) -and 
        ($_.Remove -eq "" -or $_.Remove -eq $null)
    })
    if ($noActionItems.Count -gt 0) {
        $path = Join-Path $OutputPath "${baseFileName}_NoAction_${timestamp}.csv"
        $noActionItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
        Write-Host "✓ No action items ($($noActionItems.Count)): $path" -ForegroundColor Yellow
    }
}

# ========================================
# Main Script
# ========================================

try {
    Write-Host "Reading CSV file: $CSVPath" -ForegroundColor Cyan
    $data = Import-Csv -Path $CSVPath
    
    if ($null -eq $data) {
        Write-Error "No data found in CSV file."
        exit 1
    }
    
    # Convert to array if single object
    if ($data -isnot [Array]) {
        $data = @($data)
    }
    
    Write-Host "Loaded $($data.Count) entries." -ForegroundColor Green
    
    # Filter data if requested
    $filteredData = $data
    
    if ($PolicyType) {
        Write-Host "Filtering by PolicyType: $PolicyType" -ForegroundColor Yellow
        $filteredData = $filteredData | Where-Object {$_.PolicyType -eq $PolicyType}
    }
    
    if ($ListType) {
        Write-Host "Filtering by ListType: $ListType" -ForegroundColor Yellow
        $filteredData = $filteredData | Where-Object {$_.ListType -eq $ListType}
    }
    
    if ($ObjectPattern) {
        Write-Host "Filtering by ObjectPattern: $ObjectPattern" -ForegroundColor Yellow
        $filteredData = $filteredData | Where-Object {$_.Object -match $ObjectPattern}
    }
    
    if (($PolicyType -or $ListType -or $ObjectPattern) -and ($filteredData.Count -ne $data.Count)) {
        Write-Host "After filtering: $($filteredData.Count) entries" -ForegroundColor Green
    }
    
    # Convert to array if single object after filtering
    if ($filteredData -isnot [Array]) {
        $filteredData = @($filteredData)
    }
    
    # Perform requested action
    switch ($Action) {
        "Validate" {
            Validate-CSV -Data $filteredData
        }
        
        "Summary" {
            Show-Summary -Data $filteredData
        }
        
        "FilterByType" {
            if (-not $PolicyType) {
                Write-Error "-PolicyType parameter is required for FilterByType action."
                exit 1
            }
            
            Write-Host "`n========== ENTRIES FOR POLICY TYPE: $PolicyType ==========" -ForegroundColor Cyan
            $filteredData | Format-Table -Property Object, ListType, PolicyName, TABL, MailFlowRule, DefaultConnFilter, Remove -AutoSize
        }
        
        "FilterByListType" {
            if (-not $ListType) {
                Write-Error "-ListType parameter is required for FilterByListType action."
                exit 1
            }
            
            Write-Host "`n========== ENTRIES FOR LIST TYPE: $ListType ==========" -ForegroundColor Cyan
            $filteredData | Format-Table -Property Object, PolicyType, PolicyName, TABL, MailFlowRule, DefaultConnFilter, Remove -AutoSize
        }
        
        "FindDuplicates" {
            Find-Duplicates -Data $filteredData
        }
        
        "ExportByAction" {
            Export-ByAction -Data $filteredData -OutputPath $OutputPath
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}

Write-Host "`nAnalysis completed." -ForegroundColor Cyan
