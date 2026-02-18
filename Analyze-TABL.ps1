#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Analyzes Tenant Allow/Block List (TABL) entries against exported Exchange policy CSV data.

.DESCRIPTION
    This script exports TABL entries for all list types (Sender, Url, FileHash, IP)
    and cross-references them with objects in the consolidated policy CSV exported
    by Export-ExchangePolicies.ps1.

    The output CSV includes:
    - Primary (value from TABL)
    - TABLType (Sender, Url, FileHash, IP)
    - ModifiedBy
    - Action (Allow/Block)
    - Notes
    - Policy name matches for: Anti-Phishing (Preset), Anti-Phishing, Anti-Spam, Connection Filter

.PARAMETER InputCsvPath
    Path to the consolidated policy CSV file exported from Export-ExchangePolicies.ps1.

.PARAMETER OutputPath
    Path for the TABL analysis CSV. Default: current directory with timestamp.

.PARAMETER Credential
    Optional PSCredential for Exchange Online connection.

.PARAMETER IncludeAdvancedDelivery
    Includes AdvancedDelivery entries in the TABL export (ListSubType AdvancedDelivery).

.EXAMPLE
    .\Analyze-TABL.ps1 -InputCsvPath "C:\Exports\Exchange_Policies_20260216_120000.csv"

.EXAMPLE
    .\Analyze-TABL.ps1 -InputCsvPath "C:\Exports\Exchange_Policies_20260216_120000.csv" -IncludeAdvancedDelivery
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputCsvPath,

    [string]$OutputPath = (Join-Path (Get-Location) "TABL_Analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"),

    [System.Management.Automation.PSCredential]$Credential = $null,

    [switch]$IncludeAdvancedDelivery
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

function Normalize-ObjectValue {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    return $Value.Trim().ToLowerInvariant()
}

function Get-TablPrimaryValue {
    param([PSObject]$Item)

    if ($Item.PSObject.Properties.Match("Value").Count -gt 0 -and $Item.Value) {
        return $Item.Value
    }

    if ($Item.PSObject.Properties.Match("Entry").Count -gt 0 -and $Item.Entry) {
        return $Item.Entry
    }

    if ($Item.PSObject.Properties.Match("Identity").Count -gt 0 -and $Item.Identity) {
        return $Item.Identity
    }

    return $null
}

function Get-TablPropertyValue {
    param(
        [PSObject]$Item,
        [string]$PropertyName
    )

    if ($Item.PSObject.Properties.Match($PropertyName).Count -gt 0) {
        return $Item.$PropertyName
    }

    return $null
}

# ========================================
# Main Script
# ========================================

try {
    # Connect to Exchange Online
    Connect-ExchangeOnlineIfNeeded -Credential $Credential

    # Import policy CSV
    Write-Host "Reading policy CSV: $InputCsvPath" -ForegroundColor Cyan
    $policyRows = Import-Csv -Path $InputCsvPath

    if ($null -eq $policyRows -or $policyRows.Count -eq 0) {
        Write-Error "No data found in policy CSV."
        exit 1
    }

    # Build policy lookup by object value
    $policyIndex = @{}
    foreach ($row in $policyRows) {
        $key = Normalize-ObjectValue -Value $row.Object
        if (-not $key) {
            continue
        }

        if (-not $policyIndex.ContainsKey($key)) {
            $policyIndex[$key] = @{}
        }

        $typeTable = $policyIndex[$key]
        $policyType = $row.PolicyType
        if (-not $typeTable.ContainsKey($policyType)) {
            $typeTable[$policyType] = New-Object System.Collections.Generic.HashSet[string]
        }

        if ($row.PolicyName) {
            [void]$typeTable[$policyType].Add($row.PolicyName)
        }
    }

    # Pull TABL entries
    $listTypes = @("Sender", "Url", "FileHash", "IP")
    $tablItems = New-Object System.Collections.ArrayList

    $listSubTypes = $null
    if ($IncludeAdvancedDelivery) {
        $listSubTypes = @("Tenant", "AdvancedDelivery")
    }

    foreach ($listType in $listTypes) {
        Write-Host "Retrieving TABL entries for ListType: $listType" -ForegroundColor Yellow

        $commonParams = @{ ListType = $listType; ErrorAction = "SilentlyContinue" }
        if ($listSubTypes) {
            $commonParams.ListSubType = $listSubTypes
        }

        $allowItems = Get-TenantAllowBlockListItems @commonParams -Allow
        $blockItems = Get-TenantAllowBlockListItems @commonParams -Block

        foreach ($item in @($allowItems)) {
            $item | Add-Member -NotePropertyName "_ActionOverride" -NotePropertyValue "Allow" -Force
            $item | Add-Member -NotePropertyName "_ListTypeOverride" -NotePropertyValue $listType -Force
            [void]$tablItems.Add($item)
        }

        foreach ($item in @($blockItems)) {
            $item | Add-Member -NotePropertyName "_ActionOverride" -NotePropertyValue "Block" -Force
            $item | Add-Member -NotePropertyName "_ListTypeOverride" -NotePropertyValue $listType -Force
            [void]$tablItems.Add($item)
        }
    }

    if ($tablItems.Count -eq 0) {
        Write-Warning "No TABL entries found."
        exit 0
    }

    # Build output rows
    $outputRows = New-Object System.Collections.ArrayList

    foreach ($item in $tablItems) {
        $primary = Get-TablPrimaryValue -Item $item
        if (-not $primary) {
            continue
        }

        $key = Normalize-ObjectValue -Value $primary
        $matches = $null
        if ($key -and $policyIndex.ContainsKey($key)) {
            $matches = $policyIndex[$key]
        }

        $action = Get-TablPropertyValue -Item $item -PropertyName "Action"
        if (-not $action) {
            $action = Get-TablPropertyValue -Item $item -PropertyName "_ActionOverride"
        }

        $modifiedBy = Get-TablPropertyValue -Item $item -PropertyName "ModifiedBy"
        $notes = Get-TablPropertyValue -Item $item -PropertyName "Notes"
        $tablType = Get-TablPropertyValue -Item $item -PropertyName "ListType"
        if (-not $tablType) {
            $tablType = Get-TablPropertyValue -Item $item -PropertyName "_ListTypeOverride"
        }

        $antiPhishPreset = ""
        $antiPhish = ""
        $antiSpam = ""
        $connFilter = ""

        if ($matches) {
            if ($matches.ContainsKey("Anti-Phishing (Preset)")) {
                $antiPhishPreset = ($matches["Anti-Phishing (Preset)"] | Sort-Object) -join "; "
            }
            if ($matches.ContainsKey("Anti-Phishing")) {
                $antiPhish = ($matches["Anti-Phishing"] | Sort-Object) -join "; "
            }
            if ($matches.ContainsKey("Anti-Spam")) {
                $antiSpam = ($matches["Anti-Spam"] | Sort-Object) -join "; "
            }
            if ($matches.ContainsKey("Connection Filter")) {
                $connFilter = ($matches["Connection Filter"] | Sort-Object) -join "; "
            }
        }

        [void]$outputRows.Add([PSCustomObject]@{
            Primary                         = $primary
            TABLType                        = $tablType
            ModifiedBy                      = $modifiedBy
            Action                          = $action
            Notes                           = $notes
            "Anti-Phishing (Preset) Policies" = $antiPhishPreset
            "Anti-Phishing Policies"         = $antiPhish
            "Anti-Spam Policies"             = $antiSpam
            "Connection Filter Policies"     = $connFilter
        })
    }

    # Export output
    Write-Host "`nExporting TABL analysis to: $OutputPath" -ForegroundColor Cyan
    $outputRows | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force

    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total TABL entries exported: $($outputRows.Count)" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    Write-Host "`nScript execution completed." -ForegroundColor Cyan
}
