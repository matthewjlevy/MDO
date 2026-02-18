<#
.SYNOPSIS
    Compares and selectively copies Anti-Phishing policy and rule settings from a source to destination policy.

.DESCRIPTION
    This script compares Microsoft Defender for Office 365 (MDO) Anti-Phishing policy settings between 
    a source and destination policy, then allows you to selectively choose which differences to copy. 
    
    The script performs the following steps:
    1. Retrieves both source and destination policy and rule settings
    2. Compares all tracked settings between source and destination
    3. Displays differences to the user with current vs. new values
    4. Allows interactive selection of which settings to apply (All, None, or Individual)
    5. Updates only the selected settings on the destination
    
    Settings compared and available for copying:
    
    Policy Settings (AntiPhishPolicy):
    - TargetedUsersToProtect: Users to protect against impersonation
    - TargetedDomainsToProtect: Domains to protect against impersonation
    
    Rule Settings (AntiPhishRule):
    - SentTo: Specific recipients the rule applies to
    - SentToMemberOf: Distribution groups the rule applies to
    - RecipientDomainIs: Recipient domains the rule applies to
    - ExceptIfSentTo: Specific recipients to exclude
    - ExceptIfSentToMemberOf: Distribution groups to exclude
    - ExceptIfRecipientDomainIs: Recipient domains to exclude
    
    This selective approach allows you to maintain intentional differences between policies while 
    copying only the settings you want to synchronize.

.PARAMETER SourcePolicy
    The name of the source Anti-Phishing policy to copy settings from.
    If not specified, an interactive menu will be displayed.

.PARAMETER DestinationPolicy
    The name of the destination Anti-Phishing policy to copy settings to.
    If not specified, an interactive menu will be displayed.

.PARAMETER SkipConnection
    If specified, skips the Connect-ExchangeOnline step. Use this if you're already connected.

.PARAMETER DryRun
    If specified, displays what changes would be made without actually modifying any policies or rules.
    Use this to preview the copy operation before executing it.

.EXAMPLE
    .\Copy-AntiPhishPolicySettings.ps1
    
    Runs in interactive mode. Prompts you to select source and destination Anti-Phishing policies 
    from a menu, then compares the policies and lets you choose which differences to copy.

.EXAMPLE
    .\Copy-AntiPhishPolicySettings.ps1 -SourcePolicy "MDO-Anti-phishing-strict" -DestinationPolicy "MDO-Anti-phishing-standard"
    
    Compares the two specified Anti-Phishing policies, displays differences, and prompts you to 
    select which settings to copy (options: All, None, or Select individually).

.EXAMPLE
    .\Copy-AntiPhishPolicySettings.ps1 -SourcePolicy "MDO-Anti-phishing-strict" -DestinationPolicy "MDO-Anti-phishing-standard" -SkipConnection
    
    Same as above but skips connecting to Exchange Online (assumes you're already connected).

.EXAMPLE
    .\Copy-AntiPhishPolicySettings.ps1 -SourcePolicy "MDO-Anti-phishing-strict" -DestinationPolicy "MDO-Anti-phishing-standard" -DryRun
    
    Compares Anti-Phishing policies and shows what would be copied, but doesn't make any changes.
    Perfect for previewing before making actual modifications.

.NOTES
    File Name      : Copy-AntiPhishPolicySettings.ps1
    Purpose        : Compare and selectively copy MDO Anti-Phishing policy settings
    Author         : 
    Prerequisite   : Exchange Online PowerShell V3 module
    Requires       : Exchange Online Administrator role or equivalent
    Version        : 3.0
    Last Modified  : February 2026
    
    Workflow:
    1. Connect to Exchange Online (unless -SkipConnection is used)
    2. Select or specify source and destination Anti-Phishing policies
    3. Compare all tracked settings between the two policies
    4. Display differences with current vs. new values
    5. Prompt for selection: [A]ll, [N]one, or [S]elect individually
    6. Apply only the selected changes (unless -DryRun is used)
    
.LINK
    https://learn.microsoft.com/en-us/powershell/module/exchange/get-antiphishpolicy
    https://learn.microsoft.com/en-us/powershell/module/exchange/set-antiphishpolicy
    https://learn.microsoft.com/en-us/powershell/module/exchange/get-antiphishrule
    https://learn.microsoft.com/en-us/powershell/module/exchange/set-antiphishrule
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Name of the source Anti-Phishing policy")]
    [string]$SourcePolicy,
    
    [Parameter(Mandatory=$false, HelpMessage="Name of the destination Anti-Phishing policy")]
    [string]$DestinationPolicy,
    
    [Parameter(Mandatory=$false, HelpMessage="Skip connecting to Exchange Online")]
    [switch]$SkipConnection,
    
    [Parameter(Mandatory=$false, HelpMessage="Preview changes without modifying policies")]
    [switch]$DryRun
)

# ============================================================================
# FUNCTIONS
# ============================================================================

function Show-PolicyMenu {
    <#
    .SYNOPSIS
        Displays a menu of Anti-Phishing policies and returns the selected policy name.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$Policies,
        
        [Parameter(Mandatory=$true)]
        [string]$PromptMessage
    )
    
    Write-Host "`n$PromptMessage" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $Policies.Count; $i++) {
        Write-Host "[$($i + 1)] $($Policies[$i].Name)" -ForegroundColor Yellow
    }
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    do {
        $selection = Read-Host "Enter the number of your selection (1-$($Policies.Count))"
        $selectionNum = 0
        $validInput = [int]::TryParse($selection, [ref]$selectionNum)
    } while (-not $validInput -or $selectionNum -lt 1 -or $selectionNum -gt $Policies.Count)
    
    return $Policies[$selectionNum - 1].Name
}

function Compare-ArrayValues {
    <#
    .SYNOPSIS
        Compares two arrays and determines if they are different.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [array]$Source,
        
        [Parameter(Mandatory=$false)]
        [array]$Destination
    )
    
    # Handle null/empty cases
    if (($null -eq $Source -or $Source.Count -eq 0) -and ($null -eq $Destination -or $Destination.Count -eq 0)) {
        return $false  # Both are empty, no difference
    }
    
    if ($null -eq $Source -or $Source.Count -eq 0) {
        return $true  # Source is empty but destination has values
    }
    
    if ($null -eq $Destination -or $Destination.Count -eq 0) {
        return $true  # Destination is empty but source has values
    }
    
    # Compare counts
    if ($Source.Count -ne $Destination.Count) {
        return $true
    }
    
    # Compare each element (case-insensitive for strings)
    $sourceSorted = $Source | Sort-Object
    $destSorted = $Destination | Sort-Object
    
    for ($i = 0; $i -lt $sourceSorted.Count; $i++) {
        if ($sourceSorted[$i] -ne $destSorted[$i]) {
            return $true
        }
    }
    
    return $false  # Arrays are identical
}

function Show-SettingDifference {
    <#
    .SYNOPSIS
        Displays the difference between source and destination values for a setting.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SettingName,
        
        [Parameter(Mandatory=$false)]
        [array]$SourceValue,
        
        [Parameter(Mandatory=$false)]
        [array]$DestinationValue
    )
    
    Write-Host "`n  Setting: $SettingName" -ForegroundColor Cyan
    Write-Host "  " + ("-" * 78) -ForegroundColor Gray
    
    # Display destination (current) value
    Write-Host "  Current (Destination): " -NoNewline -ForegroundColor Yellow
    if ($null -eq $DestinationValue -or $DestinationValue.Count -eq 0) {
        Write-Host "<None>" -ForegroundColor Gray
    } else {
        Write-Host "$($DestinationValue.Count) item(s)" -ForegroundColor Yellow
        foreach ($item in $DestinationValue) {
            Write-Host "      - $item" -ForegroundColor Gray
        }
    }
    
    # Display source (new) value
    Write-Host "  New (Source):          " -NoNewline -ForegroundColor Green
    if ($null -eq $SourceValue -or $SourceValue.Count -eq 0) {
        Write-Host "<None>" -ForegroundColor Gray
    } else {
        Write-Host "$($SourceValue.Count) item(s)" -ForegroundColor Green
        foreach ($item in $SourceValue) {
            Write-Host "      + $item" -ForegroundColor Gray
        }
    }
}

function Get-UserSelection {
    <#
    .SYNOPSIS
        Prompts the user to select which settings to copy.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Differences
    )
    
    if ($Differences.Count -eq 0) {
        Write-Host "`n  No differences found between source and destination." -ForegroundColor Green
        return @{}
    }
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Magenta
    Write-Host "  DIFFERENCES DETECTED - SELECT SETTINGS TO COPY" -ForegroundColor Magenta
    Write-Host ("=" * 80) -ForegroundColor Magenta
    
    # Display all differences
    foreach ($key in $Differences.Keys | Sort-Object) {
        Show-SettingDifference -SettingName $key -SourceValue $Differences[$key].Source -DestinationValue $Differences[$key].Destination
    }
    
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  SELECTION OPTIONS" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  [A] Apply ALL changes" -ForegroundColor White
    Write-Host "  [N] Apply NONE (skip all changes)" -ForegroundColor White
    Write-Host "  [S] SELECT individually which settings to apply" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    do {
        $choice = Read-Host "`nYour choice [A/N/S]"
        $choice = $choice.ToUpper()
    } while ($choice -notin @('A', 'N', 'S'))
    
    $selectedSettings = @{}
    
    switch ($choice) {
        'A' {
            # Apply all
            foreach ($key in $Differences.Keys) {
                $selectedSettings[$key] = $Differences[$key].Source
            }
            Write-Host "`n  ✓ All settings selected for copying." -ForegroundColor Green
        }
        'N' {
            # Apply none
            Write-Host "`n  ✓ No settings will be copied." -ForegroundColor Yellow
        }
        'S' {
            # Selective application
            Write-Host "`n" -NoNewline
            Write-Host ("=" * 80) -ForegroundColor Cyan
            Write-Host "  SELECT INDIVIDUAL SETTINGS" -ForegroundColor Cyan
            Write-Host ("=" * 80) -ForegroundColor Cyan
            
            $sortedKeys = $Differences.Keys | Sort-Object
            foreach ($key in $sortedKeys) {
                Write-Host "`n  Setting: $key" -ForegroundColor White
                Write-Host "    Current: " -NoNewline -ForegroundColor Yellow
                if ($null -eq $Differences[$key].Destination -or $Differences[$key].Destination.Count -eq 0) {
                    Write-Host "<None>" -ForegroundColor Gray
                } else {
                    Write-Host "$($Differences[$key].Destination.Count) item(s)" -ForegroundColor Yellow
                }
                
                Write-Host "    New:     " -NoNewline -ForegroundColor Green
                if ($null -eq $Differences[$key].Source -or $Differences[$key].Source.Count -eq 0) {
                    Write-Host "<None>" -ForegroundColor Gray
                } else {
                    Write-Host "$($Differences[$key].Source.Count) item(s)" -ForegroundColor Green
                }
                
                do {
                    $apply = Read-Host "  Apply this change? [Y/N]"
                    $apply = $apply.ToUpper()
                } while ($apply -notin @('Y', 'N'))
                
                if ($apply -eq 'Y') {
                    $selectedSettings[$key] = $Differences[$key].Source
                    Write-Host "    ✓ Will apply" -ForegroundColor Green
                } else {
                    Write-Host "    ✗ Will skip" -ForegroundColor Gray
                }
            }
            
            Write-Host "`n  ✓ Selection complete. $($selectedSettings.Count) of $($Differences.Count) settings will be copied." -ForegroundColor Green
        }
    }
    
    return $selectedSettings
}

function Copy-PolicySettings {
    <#
    .SYNOPSIS
        Compares and copies selected Anti-Phishing policy and rule settings from source to destination.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Source,
        
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        
        [Parameter(Mandatory=$false)]
        [switch]$DryRun
    )
    
    Write-Host "`n" -NoNewline
    if ($DryRun) {
        Write-Host "COMPARING & COPYING ANTI-PHISHING SETTINGS [DRY RUN MODE]" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "Source Policy:      $Source" -ForegroundColor White
        Write-Host "Destination Policy: $Destination" -ForegroundColor White
        Write-Host ("=" * 80) -ForegroundColor Yellow
    } else {
        Write-Host "COMPARING & COPYING ANTI-PHISHING SETTINGS" -ForegroundColor Green
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host "Source Policy:      $Source" -ForegroundColor White
        Write-Host "Destination Policy: $Destination" -ForegroundColor White
        Write-Host ("=" * 80) -ForegroundColor Green
    }
    
    # ========================================================================
    # STEP 1: Retrieve and Compare Policy Settings
    # ========================================================================
    
    Write-Host "`n[STEP 1] Retrieving Anti-Phishing Policy settings..." -ForegroundColor Cyan
    
    try {
        # Get both source and destination policies
        $sourcePolicy = Get-AntiPhishPolicy -Identity $Source -ErrorAction Stop
        $destPolicy = Get-AntiPhishPolicy -Identity $Destination -ErrorAction Stop
        
        Write-Host "  ✓ Retrieved source policy: $Source" -ForegroundColor Green
        Write-Host "  ✓ Retrieved destination policy: $Destination" -ForegroundColor Green
        
        # Compare policy settings
        $policyDifferences = @{}
        
        # Compare TargetedUsersToProtect
        if (Compare-ArrayValues -Source $sourcePolicy.TargetedUsersToProtect -Destination $destPolicy.TargetedUsersToProtect) {
            $policyDifferences['TargetedUsersToProtect'] = @{
                Source = $sourcePolicy.TargetedUsersToProtect
                Destination = $destPolicy.TargetedUsersToProtect
            }
        }
        
        # Compare TargetedDomainsToProtect
        if (Compare-ArrayValues -Source $sourcePolicy.TargetedDomainsToProtect -Destination $destPolicy.TargetedDomainsToProtect) {
            $policyDifferences['TargetedDomainsToProtect'] = @{
                Source = $sourcePolicy.TargetedDomainsToProtect
                Destination = $destPolicy.TargetedDomainsToProtect
            }
        }
        
    } catch {
        Write-Host "  ERROR: Failed to retrieve policy settings - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # ========================================================================
    # STEP 2: Retrieve and Compare Rule Settings
    # ========================================================================
    
    Write-Host "`n[STEP 2] Retrieving Anti-Phishing Rule settings..." -ForegroundColor Cyan
    
    try {
        # Get rules associated with both policies
        $sourceRule = Get-AntiPhishRule | Where-Object { $_.AntiPhishPolicy -eq $Source } | Select-Object -First 1
        $destinationRule = Get-AntiPhishRule | Where-Object { $_.AntiPhishPolicy -eq $Destination } | Select-Object -First 1
        
        $ruleDifferences = @{}
        
        if (-not $sourceRule) {
            Write-Host "  WARNING: No Anti-Phishing rule found for source policy '$Source'" -ForegroundColor Yellow
            Write-Host "  Skipping rule settings comparison." -ForegroundColor Yellow
        } elseif (-not $destinationRule) {
            Write-Host "  WARNING: No Anti-Phishing rule found for destination policy '$Destination'" -ForegroundColor Yellow
            Write-Host "  Skipping rule settings comparison." -ForegroundColor Yellow
        } else {
            Write-Host "  ✓ Retrieved source rule: $($sourceRule.Name)" -ForegroundColor Green
            Write-Host "  ✓ Retrieved destination rule: $($destinationRule.Name)" -ForegroundColor Green
            
            # Compare recipient scope settings
            if (Compare-ArrayValues -Source $sourceRule.SentTo -Destination $destinationRule.SentTo) {
                $ruleDifferences['SentTo'] = @{
                    Source = $sourceRule.SentTo
                    Destination = $destinationRule.SentTo
                }
            }
            
            if (Compare-ArrayValues -Source $sourceRule.SentToMemberOf -Destination $destinationRule.SentToMemberOf) {
                $ruleDifferences['SentToMemberOf'] = @{
                    Source = $sourceRule.SentToMemberOf
                    Destination = $destinationRule.SentToMemberOf
                }
            }
            
            if (Compare-ArrayValues -Source $sourceRule.RecipientDomainIs -Destination $destinationRule.RecipientDomainIs) {
                $ruleDifferences['RecipientDomainIs'] = @{
                    Source = $sourceRule.RecipientDomainIs
                    Destination = $destinationRule.RecipientDomainIs
                }
            }
            
            # Compare exception settings
            if (Compare-ArrayValues -Source $sourceRule.ExceptIfSentTo -Destination $destinationRule.ExceptIfSentTo) {
                $ruleDifferences['ExceptIfSentTo'] = @{
                    Source = $sourceRule.ExceptIfSentTo
                    Destination = $destinationRule.ExceptIfSentTo
                }
            }
            
            if (Compare-ArrayValues -Source $sourceRule.ExceptIfSentToMemberOf -Destination $destinationRule.ExceptIfSentToMemberOf) {
                $ruleDifferences['ExceptIfSentToMemberOf'] = @{
                    Source = $sourceRule.ExceptIfSentToMemberOf
                    Destination = $destinationRule.ExceptIfSentToMemberOf
                }
            }
            
            if (Compare-ArrayValues -Source $sourceRule.ExceptIfRecipientDomainIs -Destination $destinationRule.ExceptIfRecipientDomainIs) {
                $ruleDifferences['ExceptIfRecipientDomainIs'] = @{
                    Source = $sourceRule.ExceptIfRecipientDomainIs
                    Destination = $destinationRule.ExceptIfRecipientDomainIs
                }
            }
        }
        
    } catch {
        Write-Host "  ERROR: Failed to retrieve rule settings - $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # ========================================================================
    # STEP 3: Get User Selection on What to Copy
    # ========================================================================
    
    # Combine all differences
    $allDifferences = $policyDifferences + $ruleDifferences
    
    if ($allDifferences.Count -eq 0) {
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host "  NO DIFFERENCES FOUND" -ForegroundColor Green
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host "  Source and destination policies are identical for all tracked settings." -ForegroundColor White
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host ""
        return $true
    }
    
    # Get user selection
    $selectedSettings = Get-UserSelection -Differences $allDifferences
    
    if ($selectedSettings.Count -eq 0) {
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "  NO CHANGES SELECTED" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "  No settings will be copied to the destination policy." -ForegroundColor White
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host ""
        return $true
    }
    
    # ========================================================================
    # STEP 4: Apply Selected Policy Settings
    # ========================================================================
    
    # Determine which settings are policy vs rule settings
    $policySettings = @('TargetedUsersToProtect', 'TargetedDomainsToProtect')
    $policyChanges = @{}
    $ruleChanges = @{}
    
    foreach ($key in $selectedSettings.Keys) {
        if ($key -in $policySettings) {
            $policyChanges[$key] = $selectedSettings[$key]
        } else {
            $ruleChanges[$key] = $selectedSettings[$key]
        }
    }
    
    # Apply policy changes
    if ($policyChanges.Count -gt 0) {
        if ($DryRun) {
            Write-Host "`n[STEP 4] [DRY RUN] Would update Anti-Phishing Policy..." -ForegroundColor Yellow
        } else {
            Write-Host "`n[STEP 4] Updating Anti-Phishing Policy..." -ForegroundColor Cyan
        }
        
        try {
            $policyParams = @{
                Identity = $Destination
            }
            
            foreach ($key in $policyChanges.Keys) {
                $policyParams.Add($key, $policyChanges[$key])
            }
            
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would execute: Set-AntiPhishPolicy -Identity '$Destination'" -ForegroundColor Yellow
                foreach ($key in $policyChanges.Keys) {
                    $count = if ($policyChanges[$key]) { $policyChanges[$key].Count } else { 0 }
                    Write-Host "              -$key ($count item(s))" -ForegroundColor Yellow
                }
            } else {
                Set-AntiPhishPolicy @policyParams -ErrorAction Stop
                Write-Host "  ✓ Successfully updated $($policyChanges.Count) policy setting(s)." -ForegroundColor Green
            }
            
        } catch {
            Write-Host "  ERROR: Failed to update policy settings - $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    
    # ========================================================================
    # STEP 5: Apply Selected Rule Settings
    # ========================================================================
    
    if ($ruleChanges.Count -gt 0) {
        if (-not $destinationRule) {
            Write-Host "`n  WARNING: Cannot update rule settings - no destination rule found." -ForegroundColor Yellow
        } else {
            if ($DryRun) {
                Write-Host "`n[STEP 5] [DRY RUN] Would update Anti-Phishing Rule..." -ForegroundColor Yellow
            } else {
                Write-Host "`n[STEP 5] Updating Anti-Phishing Rule..." -ForegroundColor Cyan
            }
            
            try {
                $ruleParams = @{
                    Identity = $destinationRule.Name
                }
                
                foreach ($key in $ruleChanges.Keys) {
                    $ruleParams.Add($key, $ruleChanges[$key])
                }
                
                if ($DryRun) {
                    Write-Host "  [DRY RUN] Would execute: Set-AntiPhishRule -Identity '$($destinationRule.Name)'" -ForegroundColor Yellow
                    foreach ($key in $ruleChanges.Keys) {
                        $count = if ($ruleChanges[$key]) { $ruleChanges[$key].Count } else { 0 }
                        Write-Host "              -$key ($count item(s))" -ForegroundColor Yellow
                    }
                } else {
                    Set-AntiPhishRule @ruleParams -ErrorAction Stop
                    Write-Host "  ✓ Successfully updated $($ruleChanges.Count) rule setting(s)." -ForegroundColor Green
                }
                
            } catch {
                Write-Host "  ERROR: Failed to update rule settings - $($_.Exception.Message)" -ForegroundColor Red
                return $false
            }
        }
    }
    
    return $true
}

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================

Write-Host "`n"
Write-Host ("=" * 80) -ForegroundColor Magenta
Write-Host "  COPY MDO ANTI-PHISHING POLICY AND RULE SETTINGS" -ForegroundColor Magenta
Write-Host ("=" * 80) -ForegroundColor Magenta

# Connect to Exchange Online if not skipped
if (-not $SkipConnection) {
    Write-Host "`n[CONNECTING] Connecting to Exchange Online..." -ForegroundColor Cyan
    try {
        Connect-ExchangeOnline -ErrorAction Stop
        Write-Host "  Successfully connected to Exchange Online." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to connect to Exchange Online - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n[SKIPPED] Using existing Exchange Online connection." -ForegroundColor Yellow
}

# Get all Anti-Phishing policies in the tenant
Write-Host "`n[DISCOVERING] Retrieving Anti-Phishing policies from tenant..." -ForegroundColor Cyan
try {
    [array]$allPolicies = Get-AntiPhishPolicy -ErrorAction Stop | Sort-Object Name
    Write-Host "  Found $($allPolicies.Count) Anti-Phishing policy/policies." -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Failed to retrieve Anti-Phishing policies - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($allPolicies.Count -eq 0) {
    Write-Host "  ERROR: No Anti-Phishing policies found in the tenant." -ForegroundColor Red
    exit 1
}

# If source policy not provided, show interactive menu
if (-not $SourcePolicy) {
    $SourcePolicy = Show-PolicyMenu -Policies $allPolicies -PromptMessage "SELECT SOURCE POLICY (to copy FROM)"
}

# Validate source policy exists
if ($SourcePolicy -notin $allPolicies.Name) {
    Write-Host "`nERROR: Source policy '$SourcePolicy' not found in tenant." -ForegroundColor Red
    exit 1
}

# If destination policy not provided, show interactive menu
if (-not $DestinationPolicy) {
    # Filter out the source policy from destination options
    $destinationOptions = $allPolicies | Where-Object { $_.Name -ne $SourcePolicy }
    
    if ($destinationOptions.Count -eq 0) {
        Write-Host "`nERROR: No other policies available to copy to. Only one policy exists." -ForegroundColor Red
        exit 1
    }
    
    $DestinationPolicy = Show-PolicyMenu -Policies $destinationOptions -PromptMessage "SELECT DESTINATION POLICY (to copy TO)"
}

# Validate destination policy exists and is different from source
if ($DestinationPolicy -notin $allPolicies.Name) {
    Write-Host "`nERROR: Destination policy '$DestinationPolicy' not found in tenant." -ForegroundColor Red
    exit 1
}

if ($SourcePolicy -eq $DestinationPolicy) {
    Write-Host "`nERROR: Source and destination policies cannot be the same." -ForegroundColor Red
    exit 1
}

# Execute the copy operation
$success = Copy-PolicySettings -Source $SourcePolicy -Destination $DestinationPolicy -DryRun:$DryRun

# Display final result
Write-Host "\n" -NoNewline
if ($DryRun) {
    Write-Host ("=" * 80) -ForegroundColor Yellow
    if ($success) {
        Write-Host "  DRY RUN COMPLETED SUCCESSFULLY" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "  Above shows what WOULD be copied from '$SourcePolicy' to '$DestinationPolicy'." -ForegroundColor White
        Write-Host "  NO CHANGES were made. Run without -DryRun to apply changes." -ForegroundColor White
    } else {
        Write-Host "  DRY RUN COMPLETED WITH ERRORS" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "  Errors occurred during validation. Please review the errors above." -ForegroundColor White
    }
    Write-Host ("=" * 80) -ForegroundColor Yellow
} else {
    Write-Host ("=" * 80) -ForegroundColor Green
    if ($success) {
        Write-Host "  OPERATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
        Write-Host ("=" * 80) -ForegroundColor Green
        Write-Host "  All settings have been copied from '$SourcePolicy' to '$DestinationPolicy'." -ForegroundColor White
    } else {
        Write-Host "  OPERATION COMPLETED WITH ERRORS" -ForegroundColor Yellow
        Write-Host ("=" * 80) -ForegroundColor Yellow
        Write-Host "  Some settings may not have been copied. Please review the errors above." -ForegroundColor White
    }
    Write-Host ("=" * 80) -ForegroundColor Green
}
Write-Host ""
