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
        $tablAction = if ($Row.TABL -eq "Allow") { "-Allow" } else { "-Block" }
        $listType = if ($Row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "Sender" }
        
        $cmd = "New-TenantAllowBlockListItems $tablAction -Entries @('$($Row.Object)') -ListType $listType"
        $commands += $cmd
    }
    
    # Check Mail Flow Rule action
    if ($Row.MailFlowRule -eq "Create") {
        $ruleName = "Custom Rule - $($Row.Object)"
        $cmd = "# TODO: Create mail flow rule for $($Row.Object) - ListType: $($Row.ListType)"
        $commands += $cmd
    }
    
    # Check Default Connection Filter action (only IPs supported)
    if ($Row.DefaultConnFilter -eq "Add") {
        if ($Row.ListType -eq "AllowedIPs") {
            $cmd = "Set-HostedConnectionFilterPolicy -Identity 'Default' -IPAllowList @{Add='$($Row.Object)'}"
            $commands += $cmd
        } elseif ($Row.ListType -eq "BlockedIPs") {
            $cmd = "Set-HostedConnectionFilterPolicy -Identity 'Default' -IPBlockList @{Add='$($Row.Object)'}"
            $commands += $cmd
        } else {
            $cmd = "# NOTE: Connection Filter only supports IPs. Use TABL or Mail Flow Rules for domains/senders."
            $commands += $cmd
        }
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
.SYNOPSIS
    Auto-generated script from Apply-ExchangePolicies.ps1
    
.DESCRIPTION
    This script can both apply and rollback changes to Exchange Online policies.
    Generated: $(Get-Date)
    Source CSV: $CSVPath
    
.PARAMETER Rollback
    When specified, rolls back all changes made by this script.
    
.EXAMPLE
    .\ApplyChanges.ps1
    Applies all changes to Exchange Online
    
.EXAMPLE
    .\ApplyChanges.ps1 -Rollback
    Rolls back all changes previously applied
#>

param(
    [switch]`$Rollback
)

`$ErrorActionPreference = 'Continue'

Connect-ExchangeOnline

if (`$Rollback) {
    Write-Host "========== ROLLBACK MODE ==========" -ForegroundColor Yellow
    Write-Host "Rolling back policy changes..." -ForegroundColor Yellow
} else {
    Write-Host "========== APPLY MODE ==========" -ForegroundColor Cyan
    Write-Host "Applying policy changes..." -ForegroundColor Cyan
}

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
                $tablAction = if ($row.TABL -eq "Allow") { "-Allow" } else { "-Block" }
                $listType = if ($row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "Sender" }
                
                # Apply logic
                $scriptContent += "if (-not `$Rollback) {`n"
                $scriptContent += "    Write-Host 'Adding $($row.Object) to TABL as $($row.TABL)...' -ForegroundColor Yellow`n"
                $scriptContent += "    try {`n"
                $scriptContent += "        New-TenantAllowBlockListItems $tablAction -Entries @('$($row.Object)') -ListType $listType`n"
                $scriptContent += "        `$changeCount++`n"
                $scriptContent += "        Write-Host '  ✓ Added successfully' -ForegroundColor Green`n"
                $scriptContent += "    }`n"
                $scriptContent += "    catch {`n"
                $scriptContent += "        Write-Error `"Failed to add $($row.Object) to TABL: `$_`"`n"
                $scriptContent += "    }`n"
                $scriptContent += "}`n"
                
                # Rollback logic
                $scriptContent += "else {`n"
                $scriptContent += "    Write-Host 'Removing $($row.Object) from TABL ($($row.TABL))...' -ForegroundColor Yellow`n"
                $scriptContent += "    try {`n"
                $scriptContent += "        # Get the entry to find its ID`n"
                $scriptContent += "        `$entries = Get-TenantAllowBlockListItems -ListType $listType -Entry '$($row.Object)' -ErrorAction SilentlyContinue`n"
                $scriptContent += "        if (`$entries) {`n"
                $scriptContent += "            foreach (`$entry in `$entries) {`n"
                $scriptContent += "                Remove-TenantAllowBlockListItems -ListType $listType -Ids `$entry.Identity`n"
                $scriptContent += "                `$changeCount++`n"
                $scriptContent += "            }`n"
                $scriptContent += "            Write-Host '  ✓ Removed successfully' -ForegroundColor Green`n"
                $scriptContent += "        } else {`n"
                $scriptContent += "            Write-Warning '  Entry not found in TABL, may have been already removed'`n"
                $scriptContent += "        }`n"
                $scriptContent += "    }`n"
                $scriptContent += "    catch {`n"
                $scriptContent += "        Write-Error `"Failed to remove $($row.Object) from TABL: `$_`"`n"
                $scriptContent += "    }`n"
                $scriptContent += "}`n`n"
            }
            
            if ($row.DefaultConnFilter -and $row.DefaultConnFilter -ne "") {
                if ($row.ListType -eq "AllowedIPs" -or $row.ListType -eq "BlockedIPs") {
                    $param = if ($row.ListType -eq "AllowedIPs") { "IPAllowList" } else { "IPBlockList" }
                    
                    # Apply logic
                    $scriptContent += "if (-not `$Rollback) {`n"
                    $scriptContent += "    Write-Host 'Adding $($row.Object) to Default Connection Filter ($param)...' -ForegroundColor Yellow`n"
                    $scriptContent += "    try {`n"
                    $scriptContent += "        Set-HostedConnectionFilterPolicy -Identity 'Default' -$param @{Add='$($row.Object)'}`n"
                    $scriptContent += "        `$changeCount++`n"
                    $scriptContent += "        Write-Host '  ✓ Added successfully' -ForegroundColor Green`n"
                    $scriptContent += "    }`n"
                    $scriptContent += "    catch {`n"
                    $scriptContent += "        Write-Error `"Failed to add $($row.Object) to Connection Filter: `$_`"`n"
                    $scriptContent += "    }`n"
                    $scriptContent += "}`n"
                    
                    # Rollback logic
                    $scriptContent += "else {`n"
                    $scriptContent += "    Write-Host 'Removing $($row.Object) from Default Connection Filter ($param)...' -ForegroundColor Yellow`n"
                    $scriptContent += "    try {`n"
                    $scriptContent += "        Set-HostedConnectionFilterPolicy -Identity 'Default' -$param @{Remove='$($row.Object)'}`n"
                    $scriptContent += "        `$changeCount++`n"
                    $scriptContent += "        Write-Host '  ✓ Removed successfully' -ForegroundColor Green`n"
                    $scriptContent += "    }`n"
                    $scriptContent += "    catch {`n"
                    $scriptContent += "        Write-Error `"Failed to remove $($row.Object) from Connection Filter: `$_`"`n"
                    $scriptContent += "    }`n"
                    $scriptContent += "}`n`n"
                } else {
                    $scriptContent += "# NOTE: Connection Filter only supports IPs. '$($row.Object)' ($($row.ListType)) cannot be added. Use TABL or Mail Flow Rules instead.`n`n"
                }
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
        
        $scriptContent += "`n"
        $scriptContent += "if (`$Rollback) {`n"
        $scriptContent += "    Write-Host `"========== ROLLBACK COMPLETED ==========`" -ForegroundColor Yellow`n"
        $scriptContent += "    Write-Host `"Total changes rolled back: `$changeCount`" -ForegroundColor Green`n"
        $scriptContent += "} else {`n"
        $scriptContent += "    Write-Host `"========== APPLY COMPLETED ==========`" -ForegroundColor Cyan`n"
        $scriptContent += "    Write-Host `"Total changes applied: `$changeCount`" -ForegroundColor Green`n"
        $scriptContent += "    Write-Host `"`" -ForegroundColor White`n"
        $scriptContent += "    Write-Host `"To rollback these changes, run this script with -Rollback parameter:`" -ForegroundColor Yellow`n"
        $scriptContent += "    Write-Host `"  .\```$(`$MyInvocation.MyCommand.Name) -Rollback`" -ForegroundColor Cyan`n"
        $scriptContent += "}`n"
        
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
                    $listType = if ($row.Object -match "^\d+\.\d+\.\d+\.\d+(/\d+)?$") { "IP" } else { "Sender" }
                    
                    Write-Host "  Adding to TABL ($($row.TABL))..." -ForegroundColor Gray
                    if ($row.TABL -eq "Allow") {
                        New-TenantAllowBlockListItems -Allow -Entries @($row.Object) -ListType $listType
                    } else {
                        New-TenantAllowBlockListItems -Block -Entries @($row.Object) -ListType $listType
                    }
                    $successCount++
                }
                
                if ($row.DefaultConnFilter -and $row.DefaultConnFilter -ne "") {
                    if ($row.ListType -eq "AllowedIPs" -or $row.ListType -eq "BlockedIPs") {
                        Write-Host "  Adding to Default Connection Filter..." -ForegroundColor Gray
                        
                        if ($row.ListType -eq "AllowedIPs") {
                            Set-HostedConnectionFilterPolicy -Identity "Default" -IPAllowList @{Add=$row.Object}
                        } else {
                            Set-HostedConnectionFilterPolicy -Identity "Default" -IPBlockList @{Add=$row.Object}
                        }
                        $successCount++
                    } else {
                        Write-Warning "  Connection Filter only supports IPs. Skipping $($row.Object) ($($row.ListType)). Use TABL or Mail Flow Rules instead."
                    }
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
