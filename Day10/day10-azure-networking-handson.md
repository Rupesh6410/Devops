# Day 10 — Azure Networking Hands-On

Built a complete private network architecture on Azure from scratch today.
Three real problems hit along the way — each one documented precisely since
debugging these taught more than a tutorial that just works would have.

---

## Architecture Built

```
Internet
  |
  +--> Azure Firewall (public IP: 4.240.14.228)
  |         |
  |         +--> DNAT rule: port 4000 → VM private IP:80
  |         |
  |         +--> Route Table (UDR): 0.0.0.0/0 → Firewall private IP
  |
VNet (Ngnix-network, 10.0.0.0/16)
  |
  +--> default private-subnet (10.0.0.0/24)
  |         |
  |         +--> VM (no public IP, nginx on port 80)
  |         |
  |         +--> NAT Gateway (nat-pip) → outbound internet access
  |
  +--> AzureBastionSubnet
  |         |
  |         +--> Azure Bastion → developer SSH access (no public IP on VM needed)
  |
Developer → Bastion → VM (private access, port 22 never exposed publicly)
```

---

## 1. Setup — What Was Configured

**VNet:** `Ngnix-network`, `10.0.0.0/16`, Central India region

**Subnets:**
- `default` (`10.0.0.0/24`) — private subnet, VM lives here
- `AzureBastionSubnet` — required name for Bastion to work, Azure enforces this naming
- `AzureFirewallSubnet` — required name for Azure Firewall, also enforced

**Resources deployed:**
- Azure Firewall (Standard tier) with its own public IP
- Azure Bastion for developer access
- VM with no public IP, port 22 open internally only
- NAT Gateway with dedicated Standard SKU public IP (`nat-pip`)
- Firewall Policy (Standard tier) attached to the firewall
- Route Table (UDR) attached to the VM's subnet

---

## 2. Problem 1 — `apt install nginx` Timing Out via Bastion

**Symptom:**
```
Could not connect to azure.archive.ubuntu.com:80, connection timed out
E: Failed to fetch .../nginx...deb
```

**Root cause:** Azure changed its default subnet behavior **after March 31, 2026**. New VNets now default to "private subnet" mode — no outbound internet access unless explicitly configured. Pre-March 2026 tutorials (including Abhishek Veeramalla's) worked without a NAT Gateway because Azure previously gave VMs free default outbound internet access. This behavior was removed.

**Proof in the subnet config:**
```
Enable private subnet (no default outbound access) ← checked by default on new VNets
"After March 31, 2026, private subnet will be the default selection for new virtual networks."
```

**Fix:** Created a NAT Gateway with a dedicated Standard SKU public IP and associated it with the VM's subnet.

**NAT Gateway config:**
```
Name: netwroking-gateway
SKU: Standard
Outbound IP: (New) nat-pip  ← Standard SKU, required - Basic SKU not supported
VNet: Ngnix-network
Subnet: default
```

**Key learning:** Bastion and NAT Gateway solve completely different problems:
```
Bastion      → YOU connecting INTO the VM (inbound, management access)
NAT Gateway  → VM connecting OUT to the internet (outbound, packages/updates)
```
Neither replaces the other — they're complementary. Bastion being present does nothing for outbound connectivity.

**After NAT Gateway:** `sudo apt update` connected successfully. `sudo apt install nginx -y` completed. `curl http://localhost` returned nginx's default page from inside the VM.

---

## 3. Problem 2 — curl on Port 4000 Timing Out Despite DNAT Rule

**Symptom:**
```bash
curl http://4.240.14.228:4000    # times out
nc -vz 4.240.14.228 4000          # times out
ping 4.240.14.228                  # works (Layer 3 reachable, Layer 4 blocked)
```

**Diagnostic reasoning:** ping worked = VM reachable at Layer 3. curl/nc failed = something wrong at Layer 4/7 specifically on port 4000. Classic OSI layer-by-layer diagnosis — different layers, different tools, different failure modes.

**Root cause:** missing route table on the VM's subnet. Without a UDR pointing `0.0.0.0/0` to the firewall's private IP, traffic flow was asymmetric:
```
Request:  User → Firewall (public IP) → DNAT → VM ✅
Response: VM → NAT Gateway (direct outbound) → User ❌
```
The response tried to leave via the NAT Gateway instead of back through the Firewall. TCP drops asymmetric routing — the source of the request was the firewall's IP but the response came from the NAT Gateway's IP, causing the connection to fail silently.

**Fix:** Created a Route Table (UDR) and attached it to the VM's subnet:
```
Route name: route-to-firewall
Destination: 0.0.0.0/0
Next hop type: Virtual Appliance
Next hop IP: <Firewall's PRIVATE IP>  ← internal IP, not the public one
```

**Connection to theory:** this is the exact route table + firewall concept from Day 9 theory — route table decides the PATH (all traffic through the firewall), firewall decides PERMISSION (DNAT + allow rules). Both required, completely independent jobs.

---

## 4. Problem 3 — Firewall Policy Tier Mismatch

**Symptom:** DNAT rule configured, route table attached, but traffic still not forwarding correctly.

**Root cause:** Premium Firewall Policy attached to a Standard tier Firewall. Premium policies require a Premium firewall — they are incompatible. The portal allows this configuration without a clear error during setup, but rules simply don't apply correctly.

**Fix:** deleted the Premium policy, created a new Standard tier Firewall Policy, reattached to the firewall, re-added the DNAT rule.

**DNAT rule that worked:**
```
Rule collection name: dnat-rules
Priority: 100
Rule:
  Name: port-4000-to-nginx
  Source: *
  Protocol: TCP
  Destination Ports: 4000
  Destination: 4.240.14.228 (Firewall's public IP)
  Translated address: <VM's private IP>
  Translated port: 80
```

**Also added a Network rule** to explicitly allow the translated traffic:
```
Rule collection name: allow-inbound-web
Priority: 200
Rule:
  Source: *
  Protocol: TCP
  Destination Ports: 80
  Destination: <VM's private IP>
  Action: Allow
```

---

## 5. Final Verification

```bash
# From local machine:
curl http://4.240.14.228:4000
```

Returned nginx's default HTML page. Confirmed end-to-end:
```
User (local machine) → Firewall public IP:4000 → DNAT → VM private IP:80 → nginx ✅
VM outbound (apt/updates) → NAT Gateway → Internet ✅
Developer access → Bastion → VM (SSH, no public IP needed) ✅
```

---

## 6. Key Lessons — Consolidated

**Azure platform change (March 31, 2026):**
New VNets default to private subnet mode — no outbound internet access without explicit NAT Gateway or other outbound path. Pre-2026 tutorials won't mention this because the behavior didn't exist when they were recorded.

**Bastion ≠ NAT Gateway:**
Completely separate concerns. Bastion = inbound management access for developers. NAT Gateway = outbound internet for the VM itself. Both needed in a properly secured private VM setup.

**Asymmetric routing is silent but fatal for TCP:**
Request in via one path, response out via a different path = connection fails at the client side with no obvious error. Fix is always a route table forcing symmetric routing through the same device (firewall) in both directions.

**Firewall Policy tier must match Firewall tier:**
Standard Firewall = Standard Policy. Premium Firewall = Premium Policy. Mixing tiers is silently accepted by the portal but rules won't work correctly.

**NAT Gateway public IP must be Standard SKU:**
Basic SKU is not supported by NAT Gateway — will error during creation or association. Always create Standard SKU public IPs for any modern Azure resource.

---

## Status: Azure Networking Hands-On — Complete
Next: Azure Storage → Terraform (targeting Azure) → Kubernetes (AKS)
