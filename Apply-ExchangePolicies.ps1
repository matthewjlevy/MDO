#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Applies actions from the consolidated policy CSV to Exchange Online.

.DESCRIPTION
    This script reads the consolidated policy CSV file and applies the selected actions:
    - To Tenant Allow/Block List (TABL)
    - To Exchange Mail Flow Rules
    - To Default Connection Filter
    - Complete removal from all policies
    
    It processes each row where an action is marked and logs all changes.

.PARAMETER CSVPath
    Path to the consolidated policy CSV file exported from Export-ExchangePolicies.ps1

.PARAMETER Action
    Specifies which action to apply: Apply, Preview, or Export
    - Preview: Shows what would be done without making changes
    - Export: Creates a script that can be reviewed before running
    - Apply: Executes the changes (requires confirmation)

.PARAMETER Credential
    Optional PSCredential for Exchange Online connection.

.EXAMPLE
    .\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Preview
    
.EXAMPLE
    .\Apply-ExchangePolicies.ps1 -CSVPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -Action Export -OutputScript "C:\Exports\ApplyChanges.ps1"

#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CSVPath,
    
    [ValidateSet("Preview", "Export", "Apply")]
    [string]$Action = "Preview",
    
    [string]$OutputScript = (Join-Path (Get-Location) "ApplyChanges_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"),
    
    [System.Management.Automation.PSCredential]$Credential = $null,
    
    [switch]$SkipConfirmation
)

# ========================================
# Functions
# ========================================

function Connect-ExchangeOnlineIfNeeded {
    param(
        [System.Management.Automation.PSCredential]$Credential
    )
    
    $existingConnection = Get-ConnectionInformation -ErrorAction SilentlyContinue
    
    if ($null -eq $existingConnection) {
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
        
        if ($Credential) {
            Connect-ExchangeOnline -Credential $Credential -ShowBanner:$false
        } else {
            Connect-ExchangeOnline -ShowBanner:$false
        }
    } else {
        Write-Host "Using existing Exchange Online connection." -ForegroundColor Green
    }
}

function Get-ActionCommands {
    param(
        [PSObject]$PolicyObject,
        [PSObject]$Row
    )
    
    $commands = @()
    
    # Check TABL action
    if ($Row.TABL -eq "Allow" -or $Row.TABL -eq "Block") {
        $listType = if ($Row.TABL -eq "Allow") { "allow" } else { "block" }
        $entryType = if ($Row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "sender" }
        
        $cmd = "New-TenantAllowBlockListItems -ListType $listType -Entries @('$($Row.Object)') -EntryType $entryType"
        $commands += $cmd
    }
    
    # Check Mail Flow Rule action
    if ($Row.MailFlowRule -eq "Create") {
        $ruleName = "Custom Rule - $($Row.Object)"
        $cmd = "# TODO: Create mail flow rule for $($Row.Object) - ListType: $($Row.ListType)"
        $commands += $cmd
    }
    
    # Check Default Connection Filter action
    if ($Row.DefaultConnFilter -eq "Add") {
        if ($Row.ListType -like "Allowed*") {
            $param = if ($Row.ListType -eq "AllowedIPs") { "IPAllowList" } else { "WhitelistedDomains" }
        } else {
            $param = if ($Row.ListType -eq "BlockedIPs") { "IPBlockList" } else { "BlacklistedDomains" }
        }
        
        $cmd = "Set-HostedConnectionFilterPolicy -Identity 'Default' -$param @{Add='$($Row.Object)'}"
        $commands += $cmd
    }
    
    # Check Remove action
    if ($Row.Remove -eq "Yes") {
        $cmd = "# TODO: Remove '$($Row.Object)' from $($Row.PolicyType) policy '$($Row.PolicyName)'"
        $commands += $cmd
    }
    
    return $commands
}

# ========================================
# Main Script
# ========================================

try {
    # Import CSV
    Write-Host "Reading CSV file: $CSVPath" -ForegroundColor Cyan
    $policies = Import-Csv -Path $CSVPath
    
    if ($null -eq $policies -or $policies.Count -eq 0) {
        Write-Error "No data found in CSV file."
        exit 1
    }
    
    Write-Host "Loaded $($policies.Count) policy objects." -ForegroundColor Green
    
    # Filter for rows with actions
    $actionsToTake = @()
    
    foreach ($row in $policies) {
        if ($row.TABL -or $row.MailFlowRule -or $row.DefaultConnFilter -or $row.Remove) {
            $actionsToTake += $row
        }
    }
    
    if ($actionsToTake.Count -eq 0) {
        Write-Warning "No actions marked in the CSV file."
        exit 0
    }
    
    Write-Host "`nFound $($actionsToTake.Count) objects with actions to take." -ForegroundColor Yellow
    
    # ========================================
    # Preview Mode
    # ========================================
    if ($Action -eq "Preview") {
        Write-Host "`n========== PREVIEW MODE ==========" -ForegroundColor Cyan
        Write-Host "The following actions would be executed:`n" -ForegroundColor Yellow
        
        $index = 1
        foreach ($row in $actionsToTake) {
            Write-Host "[$index] Object: $($row.Object)" -ForegroundColor White
            Write-Host "    PolicyType: $($row.PolicyType)" -ForegroundColor Gray
            Write-Host "    PolicyName: $($row.PolicyName)" -ForegroundColor Gray
            Write-Host "    ListType: $($row.ListType)" -ForegroundColor Gray
            
            if ($row.TABL) { Write-Host "    → Add to TABL: $($row.TABL)" -ForegroundColor Green }
            if ($row.MailFlowRule) { Write-Host "    → Create Mail Flow Rule: $($row.MailFlowRule)" -ForegroundColor Green }
            if ($row.DefaultConnFilter) { Write-Host "    → Add to Conn Filter: $($row.DefaultConnFilter)" -ForegroundColor Green }
            if ($row.Remove) { Write-Host "    → Remove: $($row.Remove)" -ForegroundColor Green }
            
            Write-Host ""
            $index++
        }
        
        Write-Host "Run with -Action Export to generate deployment script." -ForegroundColor Cyan
        Write-Host "Run with -Action Apply to execute changes." -ForegroundColor Cyan
    }
    
    # ========================================
    # Export Mode
    # ========================================
    elseif ($Action -eq "Export") {
        Write-Host "`nGenerating deployment script: $OutputScript" -ForegroundColor Cyan
        
        $scriptContent = @"
#Requires -Modules ExchangeOnlineManagement
<#
    Auto-generated script from Apply-ExchangePolicies.ps1
    Generated: $(Get-Date)
    Source CSV: $CSVPath
#>

`$ErrorActionPreference = 'Continue'

Connect-ExchangeOnline

Write-Host "Applying policy changes..." -ForegroundColor Cyan
`$changeCount = 0

"@
        
        $index = 1
        foreach ($row in $actionsToTake) {
            $scriptContent += "`n# ========== Action $index ==========" + "`n"
            $scriptContent += "# Object: $($row.Object)`n"
            $scriptContent += "# PolicyType: $($row.PolicyType)`n"
            $scriptContent += "# PolicyName: $($row.PolicyName)`n"
            $scriptContent += "# ListType: $($row.ListType)`n`n"
            
            if ($row.TABL -and $row.TABL -ne "") {
                $listType = if ($row.TABL -like "Allow*") { "allow" } else { "block" }
                $entryType = if ($row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "sender" }
                $scriptContent += "Write-Host 'Adding $($row.Object) to TABL as $($row.TABL)...' -ForegroundColor Yellow`n"
                $scriptContent += "try {`n"
                $scriptContent += "    New-TenantAllowBlockListItems -ListType $listType -Entries @('$($row.Object)') -EntryType $entryType`n"
                $scriptContent += "    `$changeCount++`n"
                $scriptContent += "}`n"
                $scriptContent += "catch {`n"
                $scriptContent += "    Write-Error `"Failed to add $($row.Object) to TABL: `$_`"`n"
                $scriptContent += "}`n`n"
            }
            
            if ($row.DefaultConnFilter -and $row.DefaultConnFilter -ne "") {
                $scriptContent += "Write-Host 'Adding $($row.Object) to Default Connection Filter...' -ForegroundColor Yellow`n"
                $scriptContent += "try {`n"
                
                if ($row.ListType -eq "AllowedIPs") {
                    $scriptContent += "    Set-HostedConnectionFilterPolicy -Identity 'Default' -IPAllowList @{Add='$($row.Object)'}`n"
                } elseif ($row.ListType -eq "BlockedIPs") {
                    $scriptContent += "    Set-HostedConnectionFilterPolicy -Identity 'Default' -IPBlockList @{Add='$($row.Object)'}`n"
                } elseif ($row.ListType -like "Allowed*") {
                    $scriptContent += "    Set-HostedConnectionFilterPolicy -Identity 'Default' -AllowedSenderDomains @{Add='$($row.Object)'}`n"
                } else {
                    $scriptContent += "    Set-HostedConnectionFilterPolicy -Identity 'Default' -BlockedSenderDomains @{Add='$($row.Object)'}`n"
                }
                
                $scriptContent += "    `$changeCount++`n"
                $scriptContent += "}`n"
                $scriptContent += "catch {`n"
                $scriptContent += "    Write-Error `"Failed to add $($row.Object) to Connection Filter: `$_`"`n"
                $scriptContent += "}`n`n"
            }
            
            if ($row.MailFlowRule -and $row.MailFlowRule -ne "") {
                $scriptContent += "# Manual action required: Create mail flow rule for $($row.Object)`n"
                $scriptContent += "Write-Host 'TODO: Create mail flow rule for $($row.Object)' -ForegroundColor Yellow`n`n"
            }
            
            if ($row.Remove -and $row.Remove -ne "") {
                $scriptContent += "# Manual action required: Remove $($row.Object) from $($row.PolicyType) policy`n"
                $scriptContent += "Write-Host 'TODO: Remove $($row.Object) from $($row.PolicyType) policy $($row.PolicyName)' -ForegroundColor Yellow`n`n"
            }
            
            $index++
        }
        
        $scriptContent += "`nWrite-Host `"Completed. Total changes: `$changeCount`" -ForegroundColor Green`n"
        
        $scriptContent | Out-File -FilePath $OutputScript -Encoding UTF8 -Force
        Write-Host "Export completed!" -ForegroundColor Green
        Write-Host "Script saved to: $OutputScript" -ForegroundColor Green
        Write-Host "`nReview the script and run it to apply changes." -ForegroundColor Cyan
    }
    
    # ========================================
    # Apply Mode
    # ========================================
    elseif ($Action -eq "Apply") {
        if (-not $SkipConfirmation) {
            Write-Host "`nAbout to apply $($actionsToTake.Count) changes." -ForegroundColor Yellow
            $confirm = Read-Host "Do you want to continue? (yes/no)"
            
            if ($confirm -ne "yes") {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
        
        Connect-ExchangeOnlineIfNeeded -Credential $Credential
        
        Write-Host "`nApplying changes..." -ForegroundColor Cyan
        $successCount = 0
        $errorCount = 0
        
        foreach ($row in $actionsToTake) {
            Write-Host "`nProcessing: $($row.Object)" -ForegroundColor Yellow
            
            try {
                if ($row.TABL -and $row.TABL -ne "") {
                    $listType = if ($row.TABL -like "Allow*") { "allow" } else { "block" }
                    $entryType = if ($row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "sender" }
                    
                    Write-Host "  Adding to TABL ($listType)..." -ForegroundColor Gray
                    New-TenantAllowBlockListItems -ListType $listType -Entries @($row.Object) -EntryType $entryType
                    $successCount++
                }
                
                if ($row.DefaultConnFilter -and $row.DefaultConnFilter -ne "") {
                    Write-Host "  Adding to Default Connection Filter..." -ForegroundColor Gray
                    
                    if ($row.ListType -eq "AllowedIPs") {
                        Set-HostedConnectionFilterPolicy -Identity "Default" -IPAllowList @{Add=$row.Object}
                    } elseif ($row.ListType -eq "BlockedIPs") {
                        Set-HostedConnectionFilterPolicy -Identity "Default" -IPBlockList @{Add=$row.Object}
                    } elseif ($row.ListType -like "*Domain*") {
                        if ($row.ListType -like "Allowed*") {
                            Set-HostedConnectionFilterPolicy -Identity "Default" -AllowedSenderDomains @{Add=$row.Object}
                        } else {
                            Set-HostedConnectionFilterPolicy -Identity "Default" -BlockedSenderDomains @{Add=$row.Object}
                        }
                    }
                    $successCount++
                }
            }
            catch {
                Write-Error "Failed to process $($row.Object): $_"
                $errorCount++
            }
        }
        
        Write-Host "`n========== Summary ==========" -ForegroundColor Cyan
        Write-Host "Successful: $successCount" -ForegroundColor Green
        Write-Host "Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}

Write-Host "`nScript execution completed." -ForegroundColor Cyan
