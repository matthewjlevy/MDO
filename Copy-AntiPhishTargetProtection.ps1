# Connect to Exchange Online PowerShell first (as shown above)

$sourcePolicyName = "MDO-Anti-phishing-Strict"
$destinationPolicyName = "MDO-Anti-phishing-Standard"

# Get the list of protected users from the source policy
[array]$users = (Get-AntiPhishPolicy -Identity $sourcePolicyName).TargetedUsersToProtect
[array]$domains = (Get-AntiPhishPolicy -Identity $sourcePolicyName).TargetedDomainsToProtect

# Check if users were found
if ($users) {
    Write-Host "Found $($users.Count) users in $sourcePolicyName. Adding them to $destinationPolicyName."
    # Set the same list of users on the destination policy
    Set-AntiPhishPolicy -Identity $destinationPolicyName -TargetedUsersToProtect $users
    Write-Host "Successfully updated $destinationPolicyName."
} else {
    Write-Host "No targeted users found in $sourcePolicyName."
}

# Check if domains were found
if ($domains) {
    Write-Host "Found $($domains.Count) domains in $sourcePolicyName. Adding them to $destinationPolicyName."
    # Set the same list of domains on the destination policy
    Set-AntiPhishPolicy -Identity $destinationPolicyName -TargetedDomainsToProtect $domains
    Write-Host "Successfully updated $destinationPolicyName."
} else {
    Write-Host "No targeted domains found in $sourcePolicyName."
}
