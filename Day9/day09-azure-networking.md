# Day 9 — Azure Networking

Theory pass on Azure's core networking building blocks, plus a focused
revision of CIDR/subnetting/route tables beforehand since subnetting was
flagged as a weak point a few days earlier.

---

## 0. Revision — CIDR & Subnetting Formula (drilled again)

```
1. How many subnets needed? (N)
2. Bits to borrow = log2(N)
   2 subnets -> borrow 1 bit | 4 subnets -> borrow 2 bits | 8 subnets -> borrow 3 bits
3. New mask = original mask + borrowed bits
4. Addresses per subnet = 2^(32 - new mask)
5. List subnets, incrementing by (addresses per subnet) each time
```

```
/24 = 256 total (254 usable - 2 reserved: network address + broadcast)
/16 = 65,536 total
/8  = 16.7 million total
```

**Re-confirmed precision point:** "public" vs "private" subnet is NOT a
property of the IP range/CIDR itself — both typically come from the same
private block (10.x, 172.x, 192.168.x). It is determined entirely by the
**route table**: does the subnet have a route to an internet gateway
(public) or not (private)? Changing a subnet's CIDR size does NOT make it
public or private — only its routing configuration does.

`0.0.0.0/0` represents "everything else / the whole internet" because `/0`
means zero bits are fixed as network bits — every possible address matches.

---

## 1. VNet (Virtual Network)

**Problem:** need an isolated, private network space inside Azure for
resources, separate from every other customer's resources despite shared
underlying physical infrastructure.

**Answer:** a VNet — a private network defined by a CIDR block you choose,
existing entirely within your subscription.

```
VNet: 10.0.0.0/16   ↔   AWS VPC (identical concept)
```

---

## 2. Subnets

Identical concept and term to AWS — VNet divided into smaller CIDR blocks,
each tied to a purpose (web tier, app tier, db tier) and its own NSG /
route table configuration.

---

## 3. Route Tables (User Defined Routes - UDR)

**Problem:** Azure gives every subnet automatic system routes by default
(local VNet traffic + a default internet path). Sometimes this default
needs to be overridden — e.g., forcing outbound traffic through a firewall
appliance instead of going straight to the internet.

**Answer:** a custom Route Table attached to a subnet, defining explicit
next-hop rules.

```
Destination    Next Hop
0.0.0.0/0       Virtual Appliance (e.g. firewall VM) - instead of direct internet
```

**Precise job:** decides WHERE traffic goes (the path). Has no concept of
"allow" or "deny" — does NOT control whether traffic is permitted at all.

**Azure-specific nuance:** Azure subnets get sensible default system routes
automatically; a custom Route Table (UDR) is only needed to override that
default — unlike AWS, which requires an explicit route table attached to
every subnet from the start.

---

## 4. NSG (Network Security Group)

**Problem:** routing alone says nothing about whether traffic should be
permitted — a separate mechanism is needed to actually allow/deny traffic.

**Answer:** NSG — allow/deny rules evaluated by priority number (lower =
evaluated first), applied to a subnet or a specific VM's network interface.

```
Priority  Source         Destination  Port  Action
100        Any             Any          22    Allow
200        10.0.1.0/24    Any          5432  Allow
4096       Any             Any          Any   Deny (default catch-all)
```

```
NSG  ↔  AWS Security Group
```

NSGs operate purely at IP/port/protocol level — no concept of "allow this
specific command or application," same precision point corrected in an
earlier AWS NAT Gateway mock interview.

**Azure-specific nuance:** NSGs can attach at TWO levels — subnet level AND
individual VM network interface level (AWS Security Groups only attach at
the resource/instance level). Traffic can be filtered twice; both levels
must allow it to pass through.

**Precise job:** decides WHETHER traffic is allowed at all — completely
independent of Route Tables, which only decide the path.

---

## 5. ASG (Application Security Group)

**Problem:** writing NSG rules against specific VM IPs (e.g., "allow port
80 from these 20 IPs") is unmanageable — IPs change, and new VMs require
constantly editing the rule.

**Answer:** ASG — a logical group/tag assigned to VM network interfaces
(e.g., "WebTier," "AppTier"). NSG rules reference the GROUP NAME instead of
specific IPs.

```
NSG rule:
  Source: ASG-WebTier
  Destination: ASG-AppTier
  Port: 8080
  Action: Allow
```

Adding a 21st web-tier VM just means tagging its NIC with `WebTier` — the
existing rule automatically applies, no rule editing needed. ASG rules
describe INTENT ("web tier can talk to app tier"), not a constantly-stale
IP list.

**Critical distinction:** ASG is a maintainability/labeling convenience
layered ON TOP of an NSG rule — it is not a security mechanism on its own.
The NSG is what actually permits/denies; the ASG just makes the rule easier
to maintain as infrastructure changes.

```
ASG  ↔  closest AWS equivalent: referencing a Security Group itself as the
         source/destination in another Security Group's rule (similar
         intent, different mechanism, no exact 1:1 equivalent)
```

---

## 6. Application Gateway

**Problem:** a basic Load Balancer (L4) only sees IP/port — can't route
based on actual HTTP content (e.g., `/api/*` to one set of servers,
`/images/*` to another).

**Answer:** Application Gateway — an L7 load balancer, aware of HTTP/HTTPS
content, routes based on URL path, hostname, headers.

```
Application Gateway  ↔  AWS Application Load Balancer (ALB)
```

Direct connection to the L4 vs L7 health-check distinction from the
Networking module (Day 2) — Azure's standard Load Balancer = L4 (IP/port
only); Application Gateway = L7 (understands actual HTTP content).

**Also commonly handles:**
- TLS termination — decrypts HTTPS at the gateway so backend servers don't
  each need to manage certificates individually
- WAF (Web Application Firewall) — optional, inspects requests for attack
  patterns (SQL injection, XSS) before reaching the application

---

## 7. VNet Gateway (Virtual Network Gateway)

**Problem:** sometimes a VNet needs to connect to something outside Azure
entirely — an on-premises office network, or a different cloud provider —
over an encrypted, private connection rather than the open internet.

**Answer:** VNet Gateway — sits at the edge of a VNet, handles encrypted
connections to external networks.

```
VPN Gateway          → connects over the public internet, but encrypted (Site-to-Site VPN)
ExpressRoute Gateway   → connects via a dedicated private physical circuit, not over the public internet at all
```

Real scenario: a company's on-prem data center needs Azure VMs to
communicate with on-prem servers as if on the same private network, without
that traffic ever crossing the open internet.

---

## 8. VNet Peering

**Problem:** two separate VNets (e.g., "Production" and "Development")
need their resources to communicate privately, without routing through the
public internet.

**Answer:** VNet Peering — directly connects two VNets at Azure's network
fabric level; resources communicate via private IPs as if on the same
network, traffic never leaving Azure's internal backbone.

```
VNet-A (10.0.0.0/16)  <--peered-->  VNet-B (10.1.0.0/16)
```

**Critical requirement:** the two VNets' CIDR blocks must NOT overlap —
Azure couldn't otherwise tell which addresses belong to which network, and
peering would be rejected. Direct connection back to CIDR planning: when
designing multiple VNets that might eventually need to peer, non-overlapping
ranges must be chosen deliberately from the start.

```
VNet Peering  ↔  AWS VPC Peering (nearly identical concept and naming)
```

**Why faster/more secure than a VPN between two VNets:** peered traffic
travels over Azure's own private backbone, never touching the public
internet — lower latency, no exposure to internet-based threats during
transit. A VPN, by contrast, still routes through the public internet, just
encrypted.

---

## 9. Mock Scenario — Applying Everything Together

**Scenario:** web tier and app tier in two subnets of the same VNet. App
tier must ONLY accept traffic from the web tier, never directly from the
internet, AND new web-tier VMs should be addable later without editing
security rules each time.

**Correct answer, reached after one self-correction:**
- **NSG** — actual gatekeeper deciding whether traffic is allowed at all;
  this is what blocks direct internet access to the app tier
- **ASG** — maintainability layer on top of the NSG rule; tag VMs as
  `WebTier`/`AppTier`, reference the tag in the NSG rule instead of
  hardcoding IPs

**Self-correction made during this session:** initially answered "ASG +
Route Table" for this scenario — incorrect, since Route Tables only decide
the PATH traffic takes, not whether it's PERMITTED. A perfectly configured
route table does nothing to block unauthorized traffic; that's NSG's job
exclusively. Route Tables would instead be the correct answer for a
DIFFERENT requirement — e.g., "route app-tier outbound traffic through a
firewall appliance instead of straight to the internet" — a completely
separate, independent concern from the access-control question.

**Locked-in distinction:**
```
Route Table  → WHERE does traffic go (path/forwarding)
NSG          → IS traffic allowed at all (permission)
ASG          → maintainable grouping/labeling, layered ON TOP of NSG rules,
                not a security mechanism by itself
```

---

## Full Picture — All 8 Concepts Together

```
VNet (10.0.0.0/16)
  |-- Subnet (web tier, 10.0.1.0/24)
  |     |-- NSG: allows 80/443 from internet
  |     |-- ASG tag: "WebTier"
  |     `-- Route Table: default -> internet
  |-- Subnet (app tier, 10.0.2.0/24)
  |     |-- NSG: allows only from ASG-WebTier
  |     |-- ASG tag: "AppTier"
  |     `-- Route Table: default -> NAT Gateway
  |-- Application Gateway (L7, in front of web tier, TLS termination + path-based routing)
  |-- VNet Gateway (connects this VNet to an on-prem office, if needed)
  `-- VNet Peering (connects this VNet privately to a separate "Dev" VNet, if needed)
```

---

## Status: Azure Networking Theory — Complete
Next: Azure networking hands-on (create VNet, subnets, NSG, ASG via
portal/CLI) → Storage → Terraform → Kubernetes (AKS)
