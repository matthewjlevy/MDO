
# Requires -Modules ExchangeOnlineManagement
# This script updates the "ExceptIfSentToMemberOf" property of the "Standard Preset Security Policy" and "Strict Preset Security Policy" in both EOP and ATP protection policies to include the specified groups. The -whatif parameter is used to simulate the changes without applying them, allowing you to review the changes before execution.
# Remove the -whatif parameter to apply the changes.

# Reset variables
$existingValues = @()
$newValues = @()
$allValues = @()
$existingATPValues = @()
$newATPValues = @()
$allATPValues = @()

# Update Standard Preset Security Policy
$existingValues = (Get-EOPProtectionPolicyRule -Identity "Standard Preset Security Policy").ExceptIfSentToMemberOf
$newValues = "diti-mdo-standard-users@rehab.ie", "diti-mdo-strict-users@rehab.ie"
$allValues = $existingValues + $newValues
Set-EOPProtectionPolicyRule -Identity "Standard Preset Security Policy" -ExceptIfSentToMemberOf $allValues -whatif
Get-EOPProtectionPolicyRule -Identity "Standard Preset Security Policy" | Format-List Name,ExceptIfSentToMemberOf

$existingATPValues = (Get-ATPProtectionPolicyRule -Identity "Standard Preset Security Policy").ExceptIfSentToMemberOf
$newATPValues = "diti-mdo-standard-users@rehab.ie", "diti-mdo-strict-users@rehab.ie"
$allATPValues = $existingATPValues + $newATPValues
Set-ATPProtectionPolicyRule -Identity "Standard Preset Security Policy" -ExceptIfSentToMemberOf $allATPValues -whatif
Get-ATPProtectionPolicyRule -Identity "Standard Preset Security Policy" | Format-List Name,ExceptIfSentToMemberOf

# Repeat for Strict Preset Security Policy
# Reset variables
$existingValues = @()
$newValues = @()
$allValues = @()
$existingATPValues = @()
$newATPValues = @()
$allATPValues = @()

$existingValues = (Get-EOPProtectionPolicyRule -Identity "Strict Preset Security Policy").ExceptIfSentToMemberOf
$newValues = "diti-mdo-standard-users@rehab.ie", "diti-mdo-strict-users@rehab.ie"
$allValues = $existingValues + $newValues
Set-EOPProtectionPolicyRule -Identity "Strict Preset Security Policy" -ExceptIfSentToMemberOf $allValues -whatif
Get-EOPProtectionPolicyRule -Identity "Strict Preset Security Policy" | Format-List Name,ExceptIfSentToMemberOf

$existingATPValues = (Get-ATPProtectionPolicyRule -Identity "Strict Preset Security Policy").ExceptIfSentToMemberOf
$newATPValues = "diti-mdo-standard-users@rehab.ie", "diti-mdo-strict-users@rehab.ie"
$allATPValues = $existingATPValues + $newATPValues
Set-ATPProtectionPolicyRule -Identity "Strict Preset Security Policy" -ExceptIfSentToMemberOf $allATPValues -whatif
Get-ATPProtectionPolicyRule -Identity "Strict Preset Security Policy" | Format-List Name,ExceptIfSentToMemberOf

# Just get the current values for ATPBuiltProtectionPolicyRule ExceptIfSentToMemberOf
Get-ATPBuiltInProtectionRule | Format-List Name,ExceptIfSentToMemberOf
