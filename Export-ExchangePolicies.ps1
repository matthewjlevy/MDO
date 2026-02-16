#Requires -Modules ExchangeOnlineManagement
<#
.SYNOPSIS
    Exports all inbound anti-spam, anti-phish, anti-malware, and connection filter policies to a consolidated CSV.

.DESCRIPTION
    This script connects to Exchange Online and retrieves all:
    - Anti-spam policies (allowed/blocked/excluded senders and domains)
    - Anti-phish policies (allowed/blocked/excluded senders, domains, and subdomains)
    - Anti-malware policies (allowed/blocked/excluded senders and domains)
    - Default Connection Filter policy (allowed/blocked IPs)
    - Strict and Standard preset policies (all list types)
    
    The consolidated data is exported to a CSV file with columns for:
    - Object (sender, domain, IP address)
    - Source Policy Type
    - Source Policy Name
    - Current List Type (AllowedSenders, BlockedSenders, ExcludedSenders, AllowedDomains, BlockedDomains, ExcludedDomains, ExcludedSubDomains)
    - Action columns for TABL, Exchange Mail Flow Rules, Default Connection Filter, Remove

.PARAMETER OutputPath
    Path where the CSV file will be saved. Default: current directory with timestamp.

.PARAMETER Credential
    Optional PSCredential for Exchange Online connection.

.EXAMPLE
    .\Export-ExchangePolicies.ps1
    
.EXAMPLE
    .\Export-ExchangePolicies.ps1 -OutputPath "C:\Exports\policies.csv"
#>

param(
    [string]$OutputPath = (Join-Path (Get-Location) "Exchange_Policies_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"),
    [System.Management.Automation.PSCredential]$Credential = $null
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

function Add-PolicyObject {
    param(
        [System.Collections.ArrayList]$ObjectList,
        [string]$Object,
        [string]$PolicyType,
        [string]$PolicyName,
        [string]$ListType
    )
    
    if ([string]::IsNullOrWhiteSpace($Object)) {
        return
    }
    
    $exists = $ObjectList | Where-Object {
        $_.Object -eq $Object -and 
        $_.PolicyType -eq $PolicyType -and 
        $_.PolicyName -eq $PolicyName -and 
        $_.ListType -eq $ListType
    }
    
    if ($null -eq $exists) {
        $ObjectList.Add([PSCustomObject]@{
            Object      = $Object.Trim()
            PolicyType  = $PolicyType
            PolicyName  = $PolicyName
            ListType    = $ListType
            TABL        = ""
            MailFlowRule = ""
            DefaultConnFilter = ""
            Remove      = ""
        }) | Out-Null
    }
}

# ========================================
# Main Script
# ========================================

try {
    # Connect to Exchange Online
    Connect-ExchangeOnlineIfNeeded -Credential $Credential
    
    $allPolicies = [System.Collections.ArrayList]@()
    
    Write-Host "`nCollecting policies..." -ForegroundColor Cyan
    
    # ========================================
    # Collect Anti-Spam Policies
    # ========================================
    Write-Host "  - Retrieving Anti-Spam Policies..." -ForegroundColor Yellow
    
    $antiSpamPolicies = Get-MalwareFilterPolicy -ErrorAction SilentlyContinue
    foreach ($policy in $antiSpamPolicies) {
        # Anti-Spam policies may have allowed/blocked rules, but the main policy object is MalwareFilterPolicy
        # For allowed senders protection
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
    }
    
    # Anti-Spam policies using HostedContentFilterPolicy (excluding preset policies)
    $spamPolicies = Get-HostedContentFilterPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Strict|Standard" }
    foreach ($policy in $spamPolicies) {
        Write-Host "    Processing Anti-Spam policy: $($policy.Name)" -ForegroundColor Gray
        
        # Allowed Senders
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        
        # Allowed Domains
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        
        # Blocked Senders
        if ($policy.BlockedSenders) {
            foreach ($sender in $policy.BlockedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "BlockedSenders"
            }
        }
        
        # Blocked Domains
        if ($policy.BlockedSenderDomains) {
            foreach ($domain in $policy.BlockedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "BlockedDomains"
            }
        }
        
        # Excluded Senders
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        
        # Excluded Domains
        if ($policy.ExcludedSenderDomains) {
            foreach ($domain in $policy.ExcludedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
    }
    
    # ========================================
    # Collect Anti-Phishing Policies
    # ========================================
    Write-Host "  - Retrieving Anti-Phishing Policies..." -ForegroundColor Yellow
    
    $antiPhishPolicies = Get-AntiPhishPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Strict|Standard" }
    foreach ($policy in $antiPhishPolicies) {
        Write-Host "    Processing Anti-Phish policy: $($policy.Name)" -ForegroundColor Gray
        
        # Allowed Senders
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        
        # Allowed Domains
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        
        # Blocked Senders
        if ($policy.BlockedSenders) {
            foreach ($sender in $policy.BlockedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "BlockedSenders"
            }
        }
        
        # Blocked Domains
        if ($policy.BlockedSenderDomains) {
            foreach ($domain in $policy.BlockedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "BlockedDomains"
            }
        }
        
        # Excluded Senders
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        
        # Excluded Domains
        if ($policy.ExcludedSenderDomains) {
            foreach ($domain in $policy.ExcludedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
    }
    
    # ========================================
    # Collect Anti-Malware Policies
    # ========================================
    Write-Host "  - Retrieving Anti-Malware Policies..." -ForegroundColor Yellow
    
    $antiMalwarePolicies = Get-MalwareFilterPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "Strict|Standard" }
    foreach ($policy in $antiMalwarePolicies) {
        Write-Host "    Processing Anti-Malware policy: $($policy.Name)" -ForegroundColor Gray
        
        # Allowed Senders
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Malware" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        
        # Allowed Domains
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Malware" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        
        # Excluded Senders
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Malware" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        
        # Excluded Domains
        if ($policy.ExcludedSenderDomains) {
            foreach ($domain in $policy.ExcludedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Malware" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
    }
    
    # ========================================
    # Collect Default Connection Filter Policy
    # ========================================
    Write-Host "  - Retrieving Connection Filter Policy..." -ForegroundColor Yellow
    
    $connFilterPolicy = Get-HostedConnectionFilterPolicy | Where-Object { $_.IsDefault -eq $true } -ErrorAction SilentlyContinue
    if ($connFilterPolicy) {
        Write-Host "    Processing Connection Filter policy: $($connFilterPolicy.Name)" -ForegroundColor Gray
        
        # Allowed IPs and Senders
        if ($connFilterPolicy.IPAllowList) {
            foreach ($ip in $connFilterPolicy.IPAllowList) {
                Add-PolicyObject -ObjectList $allPolicies -Object $ip -PolicyType "Connection Filter" -PolicyName $connFilterPolicy.Name -ListType "AllowedIPs"
            }
        }
        
        # Blocked IPs
        if ($connFilterPolicy.IPBlockList) {
            foreach ($ip in $connFilterPolicy.IPBlockList) {
                Add-PolicyObject -ObjectList $allPolicies -Object $ip -PolicyType "Connection Filter" -PolicyName $connFilterPolicy.Name -ListType "BlockedIPs"
            }
        }
    }
    
    # ========================================
    # Collect Preset Policies (Strict and Standard)
    # ========================================
    Write-Host "  - Retrieving Preset Policies (Strict/Standard)..." -ForegroundColor Yellow
    
    # Strict and Standard Anti-Spam Policies
    $presetSpamPolicies = Get-HostedContentFilterPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Strict|Standard" }
    foreach ($policy in $presetSpamPolicies) {
        Write-Host "    Processing Preset Anti-Spam policy: $($policy.Name)" -ForegroundColor Gray
        
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        if ($policy.BlockedSenders) {
            foreach ($sender in $policy.BlockedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "BlockedSenders"
            }
        }
        if ($policy.BlockedSenderDomains) {
            foreach ($domain in $policy.BlockedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "BlockedDomains"
            }
        }
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        if ($policy.ExcludedSenderDomains) {
            foreach ($domain in $policy.ExcludedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Spam (Preset)" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
    }
    
    # Strict and Standard Anti-Phishing Policies
    $presetPhishPolicies = Get-AntiPhishPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Strict|Standard" }
    foreach ($policy in $presetPhishPolicies) {
        Write-Host "    Processing Preset Anti-Phish policy: $($policy.Name)" -ForegroundColor Gray
        
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        if ($policy.BlockedSenders) {
            foreach ($sender in $policy.BlockedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "BlockedSenders"
            }
        }
        if ($policy.BlockedSenderDomains) {
            foreach ($domain in $policy.BlockedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "BlockedDomains"
            }
        }
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        if ($policy.ExcludedDomains) {
            foreach ($domain in $policy.ExcludedDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
        if ($policy.ExcludedSubDomains) {
            foreach ($domain in $policy.ExcludedSubDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Phishing (Preset)" -PolicyName $policy.Name -ListType "ExcludedSubDomains"
            }
        }
    }
    
    # Strict and Standard Anti-Malware Policies
    $presetMalwarePolicies = Get-MalwareFilterPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Strict|Standard" }
    foreach ($policy in $presetMalwarePolicies) {
        Write-Host "    Processing Preset Anti-Malware policy: $($policy.Name)" -ForegroundColor Gray
        
        if ($policy.AllowedSenders) {
            foreach ($sender in $policy.AllowedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Malware (Preset)" -PolicyName $policy.Name -ListType "AllowedSenders"
            }
        }
        if ($policy.AllowedSenderDomains) {
            foreach ($domain in $policy.AllowedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Malware (Preset)" -PolicyName $policy.Name -ListType "AllowedDomains"
            }
        }
        if ($policy.ExcludedSenders) {
            foreach ($sender in $policy.ExcludedSenders) {
                Add-PolicyObject -ObjectList $allPolicies -Object $sender -PolicyType "Anti-Malware (Preset)" -PolicyName $policy.Name -ListType "ExcludedSenders"
            }
        }
        if ($policy.ExcludedSenderDomains) {
            foreach ($domain in $policy.ExcludedSenderDomains) {
                Add-PolicyObject -ObjectList $allPolicies -Object $domain -PolicyType "Anti-Malware (Preset)" -PolicyName $policy.Name -ListType "ExcludedDomains"
            }
        }
    }
    
    # ========================================
    # Export to CSV
    # ========================================
    if ($allPolicies.Count -eq 0) {
        Write-Host "`nNo policy objects found." -ForegroundColor Yellow
    } else {
        Write-Host "`nExporting $($allPolicies.Count) objects to CSV..." -ForegroundColor Cyan
        
        # Sort for better readability
        $allPolicies = $allPolicies | Sort-Object -Property PolicyType, PolicyName, Object
        
        # Export to CSV
        $allPolicies | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Force
        
        Write-Host "Export completed successfully!" -ForegroundColor Green
        Write-Host "Output file: $OutputPath" -ForegroundColor Green
        Write-Host "Total objects exported: $($allPolicies.Count)" -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    Write-Host "`nScript execution completed." -ForegroundColor Cyan
}
