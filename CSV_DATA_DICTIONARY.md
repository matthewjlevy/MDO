# CSV Data Dictionary

Reference guide for the consolidated Exchange Online policies CSV output.

## Column Descriptions

### Object (Column 1)
**Data Type:** String  
**Description:** The sender address, domain, or IP address from the policy list.  

**Examples:**
- `user@example.com` - Email address (sender)
- `example.com` - Domain name  
- `192.168.1.100` - IPv4 address
- `192.168.1.0/24` - IPv4 CIDR range
- `2001:db8::/32` - IPv6 CIDR range

**Valid Values:**
- Email address format: `user@domain.com`
- Domain format: `domain.com` (may include subdomains)
- IP addresses: Single IP or CIDR notation
- Wildcards: Some policies may include partial matches

---

### PolicyType (Column 2)
**Data Type:** String  
**Description:** The type of Exchange Online security policy this object comes from.  

**Valid Values:**
- `Anti-Spam` - HostedContentFilterPolicy (regular anti-spam filtering)
- `Anti-Phishing` - AntiPhishPolicy (regular anti-phishing protection)
- `Anti-Malware` - MalwareFilterPolicy (regular malware protection)
- `Connection Filter` - HostedConnectionFilterPolicy (IP-based filtering)
- `Anti-Spam (Preset)` - Standard/Strict Preset Anti-Spam Security Policy
- `Anti-Phishing (Preset)` - Standard/Strict Preset Anti-Phishing Security Policy
- `Anti-Malware (Preset)` - Standard/Strict Preset Anti-Malware Security Policy

**Notes:**
- Each policy type has different capabilities
- Some object types only apply to certain policies
- TABL supports Anti-Spam and Anti-Phishing objects best
- Preset policies are Microsoft-managed security baselines
- Regular and Preset policies are handled separately to avoid duplicates

---

### PolicyName (Column 3)
**Data Type:** String  
**Description:** The specific name of the policy containing this object.  

**Examples:**
- `Default` - Built-in or default policy
- `Policy1`, `Policy2` - Custom named policies
- `Executives` - Role-based policy
- `Partners` - Business unit policy
- `Standard Preset Security Policy` - Microsoft-managed preset
- `Strict Preset Security Policy` - Microsoft-managed preset

**Notes:**
- Exchange Online usually has one "Default" policy
- Additional policies can be created for specific org units
- Policy names are case-sensitive in Exchange Online
- Preset policies have fixed names provided by Microsoft

---

### ListType (Column 4)
**Data Type:** String  
**Description:** The specific type of allow/block list this object is in.  

**Valid Values:**
- `AllowedSenders` - List of allowed senders (sender addresses)
- `BlockedSenders` - List of blocked senders (sender addresses)
- `ExcludedSenders` - List of excluded senders (skip policy rules)
- `AllowedDomains` - List of allowed domains
- `BlockedDomains` - List of blocked domains
- `ExcludedDomains` - List of excluded domains (skip policy rules)
- `ExcludedSubDomains` - List of excluded subdomains (Anti-Phishing only)
- `AllowedIPs` - List of allowed IP addresses/ranges
- `BlockedIPs` - List of blocked IP addresses/ranges

**Mapping by PolicyType:**

| PolicyType | Supported ListTypes |
|---|---|
| Anti-Spam | AllowedSenders, BlockedSenders, ExcludedSenders, AllowedDomains, BlockedDomains, ExcludedDomains |
| Anti-Phishing | AllowedSenders, BlockedSenders, ExcludedSenders, AllowedDomains, BlockedDomains, ExcludedDomains, ExcludedSubDomains |
| Anti-Malware | AllowedSenders, ExcludedSenders, AllowedDomains, ExcludedDomains |
| Connection Filter | AllowedIPs, BlockedIPs |
| Anti-Spam (Preset) | AllowedSenders, BlockedSenders, ExcludedSenders, AllowedDomains, BlockedDomains, ExcludedDomains |
| Anti-Phishing (Preset) | AllowedSenders, BlockedSenders, ExcludedSenders, AllowedDomains, BlockedDomains, ExcludedDomains, ExcludedSubDomains |
| Anti-Malware (Preset) | AllowedSenders, ExcludedSenders, AllowedDomains, ExcludedDomains |

**Understanding Excluded Lists:**
- **Excluded Senders/Domains**: Skip the policy rules - messages are not filtered
- **Allowed Senders/Domains**: Automatically pass through (positive whitelist)
- **Blocked Senders/Domains**: Automatically rejected (negative blacklist)

---

### TABL (Column 5)
**Data Type:** String  
**Description:** Action column for Tenant Allow/Block List placement.  

**Valid Values:**
- (empty/blank) - No action for TABL
- `Allow` - Add to TABL as allowed entry
- `Block` - Add to TABL as blocked entry

**Decision Guide:**
- Use `Allow` for trusted partners, internal domains, or false negatives
- Use `Block` for known threats, spam sources, or false positives
- Leave blank if not using TABL

**Notes:**
- TABL entries take precedence over policy rules
- Changes take 30-60 minutes to propagate
- TABL has size limits (check Microsoft documentation)
- Recommended for permanent, organization-wide decisions
- Cannot contain wildcard entries

**Example Entries:**
- Email: `partner@trusted.com` → TABL: `Allow`
- Domain: `trusted.com` → TABL: `Allow`
- IP: `192.168.1.100` → TABL: `Allow` (Connection Filter only)
- Malware domain: `malware.net` → TABL: `Block`

---

### MailFlowRule (Column 6)
**Data Type:** String  
**Description:** Action column for Exchange mail flow rule (transport rule) creation.  

**Valid Values:**
- (empty/blank) - No action for mail flow rules
- `Create` - Create a mail flow rule for this object

**Decision Guide:**
- Use when you need conditional logic
- Use for complex rule conditions
- Use for targeted department or user group rules
- Use for rate limiting or specific quarantine actions

**Notes:**
- Manual rule creation required at this time
- Provides more flexibility than TABL
- Can have multiple conditions and actions
- Takes immediate effect
- Better for temporary or test policies

**Common Use Cases:**
- Route messages from specific domain to specific mailbox
- Add disclaimer for external email
- Apply conditional encryption
- Quarantine for human review without blocking
- Create approval workflow

**Example Workflow:**
1. Mark entry: `Create` in MailFlowRule
2. Apply script generates TODO comment
3. Manually create rule in Exchange admin center
4. Define additional conditions as needed

---

### DefaultConnFilter (Column 7)
**Data Type:** String  
**Description:** Action column for Default Connection Filter Policy modification.  

**Valid Values:**
- (empty/blank) - No action for connection filter
- `Add` - Add to appropriate IP list in connection filter

**Decision Guide:**
- Use `Add` for trusted sending IPs (whitelisting)
- Use `Add` for known spam source IPs (blacklisting)
- Decide based on ListType (Allowed vs Blocked)

**Technical Details:**
- Applied at SMTP receive connector level
- IP-based filtering only (not for email addresses)
- Takes immediate effect
- Applied before content filtering policies

**Important Restrictions:**
- Only IP addresses, not email addresses or domains
- Only for `AllowedIPs` and `BlockedIPs` in Connection Filter policy
- Email/domain filtering should use TABL or mail flow rules instead

**Example:**
- `192.168.1.100` with ListType `AllowedIPs` → DefaultConnFilter: `Add`
- `10.0.0.0/8` with ListType `BlockedIPs` → DefaultConnFilter: `Add`

---

### Remove (Column 8)
**Data Type:** String  
**Description:** Action column to remove entry from current policy.  

**Valid Values:**
- (empty/blank) - Keep in current policy
- `Yes` - Remove from PolicyName/PolicyType
- `No` - Explicitly keep (same as blank)

**Decision Guide:**
- Use `Yes` only after ensuring object is migrated elsewhere
- Use `Yes` to clean up duplicate entries
- Use `Yes` to consolidate policies
- Typically paired with action in another column

**Important:**
- Always have backup/alternative before removing
- Verify TABL contains entry before removing from policy
- Removing may affect mail flow if not done carefully

**Recommended Workflow:**
1. Mark TABL: `Allow` or `Block`
2. Wait for TABL to replicate (30-60 minutes)
3. Then mark Remove: `Yes`
4. Run update

---

## Valid Action Combinations

### Recommended
✓ One action per row (preferred)
```
Object: partner@trusted.com
Action: TABL → Allow
Action: Remove → (empty)
```

### Possible but Rare
- TABL + Remove (migrate to TABL, remove from policy)
- MailFlowRule + Remove (create rule, remove from policy)

### Not Recommended
✗ Multiple actions on one row
```
Object: example.com
Action: TABL → Allow
Action: MailFlowRule → Create  ❌ Only pick one
Action: DefaultConnFilter → Add ❌ Only pick one
```

---

## Data Validation Rules

| Column | Required | Data Type | Min Length | Max Length | Notes |
|---|---|---|---|---|---|
| Object | Yes | String | 1 | 320 | Email, domain, or IP format |
| PolicyType | Yes | String | 3 | 50 | Must include: Anti-Spam, Anti-Phishing, Anti-Malware, Connection Filter, and (Preset) variants |
| PolicyName | Yes | String | 1 | 64 | Policy must exist in Exchange Online |
| ListType | Yes | String | 5 | 20 | Must be valid list type (see Common Values Reference) |
| TABL | No | String | 0 | 5 | Allow, Block, or blank |
| MailFlowRule | No | String | 0 | 6 | Create or blank |
| DefaultConnFilter | No | String | 0 | 3 | Add or blank |
| Remove | No | String | 0 | 3 | Yes, No, or blank |

---

## Common Values Reference

### By PolicyType:
```
Anti-Spam (HostedContentFilterPolicy)
├─ AllowedSenders
├─ AllowedDomains
├─ BlockedSenders
├─ BlockedDomains
├─ ExcludedSenders
└─ ExcludedDomains

Anti-Phishing (AntiPhishPolicy)
├─ AllowedSenders
├─ AllowedDomains
├─ BlockedSenders
├─ BlockedDomains
├─ ExcludedSenders
├─ ExcludedDomains
└─ ExcludedSubDomains

Anti-Malware (MalwareFilterPolicy)
├─ AllowedSenders
├─ AllowedDomains
├─ ExcludedSenders
└─ ExcludedDomains

Anti-Spam (Preset)
├─ AllowedSenders
├─ AllowedDomains
├─ BlockedSenders
├─ BlockedDomains
├─ ExcludedSenders
└─ ExcludedDomains

Anti-Phishing (Preset)
├─ AllowedSenders
├─ AllowedDomains
├─ BlockedSenders
├─ BlockedDomains
├─ ExcludedSenders
├─ ExcludedDomains
└─ ExcludedSubDomains

Anti-Malware (Preset)
├─ AllowedSenders
├─ AllowedDomains
├─ ExcludedSenders
└─ ExcludedDomains

Connection Filter (HostedConnectionFilterPolicy)
├─ AllowedIPs
└─ BlockedIPs
```

### By ListType:
```
AllowedSenders → Objects explicitly allowed
AllowedDomains → Entire domains allowed
BlockedSenders → Objects explicitly blocked
BlockedDomains → Entire domains blocked
ExcludedSenders → Senders excluded from policy scanning
ExcludedDomains → Domains excluded from policy scanning
ExcludedSubDomains → Subdomains excluded from phishing policy (Anti-Phishing only)
AllowedIPs → IP addresses/ranges allowed
BlockedIPs → IP addresses/ranges blocked
```

---

## Examples by Scenario

### Scenario 1: Email from Partner Company (Trusted)
```csv
Object,PolicyType,PolicyName,ListType,TABL,MailFlowRule,DefaultConnFilter,Remove
partner@trusted.com,Anti-Spam,Default,AllowedSenders,Allow,,,
partner.com,Anti-Spam,Default,AllowedDomains,Allow,,,
```

### Scenario 2: Known Malware Source
```csv
Object,PolicyType,PolicyName,ListType,TABL,MailFlowRule,DefaultConnFilter,Remove
malware.net,Anti-Malware,Default,BlockedDomains,Block,,,
badactor@evil.com,Anti-Phishing,Default,BlockedSenders,Block,,,
```

### Scenario 3: Migrate to TABL and Remove from Policy
```csv
Object,PolicyType,PolicyName,ListType,TABL,MailFlowRule,DefaultConnFilter,Remove
manager@corp.com,Anti-Spam,Policy1,AllowedSenders,Allow,,,Yes
internal.local,Anti-Spam,Policy1,AllowedDomains,Allow,,,Yes
```

### Scenario 4: IP-based Connection Filter
```csv
Object,PolicyType,PolicyName,ListType,TABL,MailFlowRule,DefaultConnFilter,Remove
192.168.1.1/32,Connection Filter,Default,AllowedIPs,,,,
203.0.113.0/24,Connection Filter,Default,BlockedIPs,,,,
```

---

## Troubleshooting Guide

### Question: Can I have the same object in multiple policies?
**Answer:** Yes, and it's common. Each will appear as a separate row in the CSV. You can consolidate by:
1. Add to TABL (one central location)
2. Wait for replication (~30-60 minutes)
3. Remove from individual policies

### Question: What if I don't know what an object should do?
**Answer:** Leave the action columns empty initially:
1. Run preview mode
2. Ask stakeholder about object
3. Update CSV after confirmation
4. Re-run preview and apply

### Question: Can I use wildcards in TABL?
**Answer:** No. TABL does not support wildcards. Use:
- Exact domain: `trusted.com`
- Exact sender: `user@trusted.com`
- IP/CIDR: `192.168.1.0/24`

### Question: How long do changes take?
**Answer:**
- TABL: 30-60 minutes to replicate globally
- Mail Flow Rules: Immediate (after creation)
- Connection Filter: Immediate
- Policy removals: Immediate

---

## Revision History

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-02-16 | Initial CSV format documentation |

