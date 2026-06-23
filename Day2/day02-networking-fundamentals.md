# Day 2 — Networking For DevOps

Continuing first-principles learning — understanding the problem each concept
solves before memorizing the tool/command.

---

## 1. Cron Jobs

**Problem:** need tasks to run automatically on a schedule, without manually
typing commands at exact times forever.

**Answer:** `cron` — a background daemon (managed by systemd, same pattern as
nginx) that checks every minute if anything is scheduled to run.

```bash
sudo systemctl status cron
crontab -e
```

5-field schedule syntax:
```
* * * * *
| | | | |
| | | | └── day of week (0-6, Sun=0)
| | | └──── month (1-12)
| | └────── day of month (1-31)
| └──────── hour (0-23)
└────────── minute (0-59)
```

```
0 2 * * *     → daily at 2:00 AM (e.g. backups)
*/5 * * * *   → every 5 minutes (e.g. health checks)
```

**Why cron > a sleep-loop script:** cron runs each scheduled execution as a
fresh independent process managed by systemd. If one run fails, the next
scheduled run still happens — no single point of failure like a long-running
script that could crash and never restart.

---

## 2. SSH Key-Based Authentication

**Problem:** password logins can be brute-forced/stolen. Need something far
harder to compromise for server access.

**Answer:** public-key cryptography — a private key (never leaves your
machine) and a public key (shared freely, placed on servers).

```bash
ssh-keygen -t ed25519 -C "email@example.com"
cat ~/.ssh/id_ed25519.pub      # safe to share
# id_ed25519 (no .pub) = PRIVATE, never share
```

The server issues a cryptographic challenge only the matching private key can
answer — public key alone can't be reverse-engineered to derive the private
key, even with major computing power. This is exactly the model behind AWS's
`.pem` key files for EC2 access.

---

## 3. OSI Model / TCP-IP — Why Layers Exist

**Problem:** two computers need to communicate reliably across complex,
unreliable networks. Without separation of concerns, every application would
need to handle raw signals, addressing, AND error correction itself — chaos.

**Answer:** break networking into layers, each with one job:

```
OSI (7 layers, conceptual)      TCP/IP (4 layers, what's actually used)
7. Application (HTTP, DNS)  ┐
6. Presentation               ├── Application
5. Session                  ┘
4. Transport (TCP, UDP)      ── Transport
3. Network (IP)               ── Internet
2. Data Link (Ethernet)      ┐
1. Physical (cables/wifi)     ┴── Network Access
```

**Why this matters practically:** when something breaks, the model tells you
*where* to look. DNS not resolving = Application layer. Port not listening =
Transport layer. Packets not reaching destination = Network layer.

**Correct outage diagnosis order (bottom-up, since a lower-layer failure
makes everything above it irrelevant):**
```bash
ping <server-ip>              # L3 - is the server reachable at all?
sudo ss -tulnp | grep 443      # L4 - is the port actually listening?
curl -I https://yoursite.com  # L7 - is the app responding correctly?
```

### TCP vs UDP — the actual mechanism, not just "reliable vs fast"

**TCP reliability comes from multiple layered mechanisms, not just the
handshake:**

1. **Three-way handshake** (connection setup only):
```
Client → SYN (seq=100)
Server → SYN-ACK (seq=500, ack=101)
Client → ACK (ack=501)
```

2. **Per-packet acknowledgment during transfer** — every chunk sent gets a
   sequence number; receiver ACKs it. No ACK within timeout → sender
   retransmits. **This, not just the handshake, is the core reliability
   mechanism.**

3. **Ordering enforcement** — out-of-order packets get buffered and held
   until missing earlier packets arrive, before being passed to the app.

4. **Congestion control** — TCP deliberately slows its send rate when it
   detects network congestion.

**Why TCP is slower:** every one of the above adds overhead — handshake RTTs,
waiting for ACKs/retransmitting, buffering for order, throttling under
congestion. UDP skips all of this entirely — fires packets, no guarantees,
no ordering, no resend. That's the actual trade: TCP = correctness at the
cost of speed; UDP = speed at the cost of guarantees.

---

## 4. DNS — Why a Hierarchy, Not One Giant Database

**Problem:** humans can't memorize IP addresses for every site; need a
name → IP translation system that scales to billions of domains.

**Resolver doesn't need global knowledge** — it only has ONE fixed,
hardcoded starting point: the 13 root servers. From there, every server in
the chain only needs to know "who's one level more specific than me"
(delegation), not the full picture.

```bash
dig +trace github.com
```

Resolution chain observed on my own machine:
```
Root servers → "I don't know github.com, but here's who handles .com"
.com TLD servers → "I don't know the IP, but here's github.com's own nameservers"
github.com's nameservers (AWS Route53 + NS1) → "Here's the actual A record: 20.207.73.82"
```

Each `NS` record returned at every step is a **delegation** — "go ask someone
more specific" — not the final answer. Only the last hop (the authoritative
nameserver) returns the real `A` record.

**Why hierarchy, not a single central DB:** a single server holding every
domain on Earth would be (a) an impossible single point of failure for the
entire internet, and (b) overwhelmed instantly by global query volume. The
distributed/delegated structure spreads load and removes any single failure
point.

**Why DNS commonly uses UDP, not TCP:** queries are tiny and need to be fast;
if one fails, the client just retries — the overhead of TCP's handshake
would slow down something that should be near-instant.

---

## 5. IP Addressing, CIDR & Subnetting

### IPv4 structure
32 bits, written as 4 octets (8 bits each, 0–255):
```
172.20.10.5  →  8bit.8bit.8bit.8bit = 32 bits total
```

### Subnet mask — splits an IP into NETWORK portion + HOST portion
```
255.255.255.0  =  11111111.11111111.11111111.00000000
                  (network - fixed)         (host - variable)
```

CIDR notation (`/24`) is shorthand for the subnet mask:
```
/24 = 255.255.255.0   → 2^8  = 256 addresses (254 usable)
/16 = 255.255.0.0     → 2^16 = 65,536 addresses
/8  = 255.0.0.0       → 2^24 addresses
```

Every subnet reserves 2 addresses: the **network address** (first, identifies
the network itself) and the **broadcast address** (last, reaches every
device on that network at once).

### Subnetting formula — how to split a CIDR block into N subnets

```
1. Start with given CIDR (e.g. /16 = 16 free bits)
2. Decide how many subnets needed (e.g. 4)
3. Bits to borrow = log2(number of subnets)   →  4 subnets = 2^2 → borrow 2 bits
4. New mask = original + borrowed bits         →  /16 + 2 = /18
5. Addresses per subnet = 2^(remaining free bits)
6. List subnets by incrementing through the address space in steps of (subnet size)
```

Example — `10.0.0.0/16` into 4 subnets (2 public, 2 private):
```
10.0.0.0/18    → Public  (AZ-a)
10.0.64.0/18   → Public  (AZ-b)
10.0.128.0/18  → Private (AZ-a)
10.0.192.0/18  → Private (AZ-b)
```

**Key correction noted:** the number of bits to borrow is recalculated EVERY
time based on how many subnets THIS specific scenario needs — never assume
it carries over from a previous example. Subnetting math is still a weak
point — deferring full practice to when I'm allocating real subnets in AWS.

**Important precision:** "public" vs "private" subnet is NOT determined by
the IP range itself — both typically come from the same private CIDR block.
It's determined by the **route table**: does the subnet have a route to an
Internet Gateway (public) or only to a NAT Gateway / no internet route at all
(private)?

---

## 6. Private IP Ranges & Why IPv4 Hasn't Run Out

IPv4 has only ~4.3 billion addresses (`2^32`) — nowhere near enough for
billions of devices globally. Solved by:

**Reserved private ranges (reused infinitely across isolated networks):**
```
10.0.0.0    – 10.255.255.255    (10.0.0.0/8)
172.16.0.0  – 172.31.255.255    (172.16.0.0/12)
192.168.0.0 – 192.168.255.255   (192.168.0.0/16)
```
Millions of separate networks (homes, companies, AWS VPCs) reuse these exact
same ranges with zero conflict — because **isolation**, not global
uniqueness, is what makes private IPs work. My own home WiFi (`192.168.0.101`)
is reused by millions of other households worldwide.

**IPv6** is the real long-term fix — 128 bits → ~340 undecillion addresses,
designed so the world never runs out again.

---

## 7. NAT (Network Address Translation)

**One-line definition:** NAT lets many private devices share one public IP,
by having the router rewrite and track address/port info for every
connection passing through it.

**Mechanism:**
```
Outgoing: Private IP:port → Router rewrites → Public IP:NEW port → Internet
Incoming: Internet → Public IP:port → Router looks up its translation table
        → rewrites back to → original Private IP:port
```

The router keeps a **translation table** mapping (public IP, public port) ↔
(private IP, private port) for every active connection. A connection is
identified by the full 4-part tuple (source IP, source port, dest IP, dest
port) — NOT IP alone. This is exactly why multiple devices sharing one public
IP never get their responses mixed up.

**Verified:** `curl ifconfig.me` (public IP) vs `ip a` (private IP,
`192.168.0.101`) showed two completely different numbers — proof NAT is
actively translating in real time.

**Two benefits:** (1) IP conservation — one public IP serves an entire
household/company, (2) security side-effect — private devices are not
directly reachable from the internet unless explicitly forwarded.

**CGNAT (Carrier-Grade NAT):** mobile carriers run the same NAT concept at
massive scale — hundreds/thousands of different customers can share one
carrier public IP. Unlike a home router, I have zero administrative control
over carrier NAT (can't port-forward) — this is why self-hosting something
from mobile data directly often just doesn't work, while it can work on
home WiFi with port forwarding configured.

**AWS connection:** an AWS NAT Gateway is the exact same mechanism — lets
private EC2 instances (no public IP) reach the internet for updates, while
remaining unreachable from outside. The NAT Gateway itself sits in a public
subnet with its own public IP; the private instance never becomes public —
traffic just routes *through* the NAT Gateway.

**Correction from mock interview:** security groups operate at IP/port
level only — there is no such thing as a rule "for `apt upgrade`." `apt`
traffic is just normal outbound HTTPS (port 443) like anything else. The
actual setup requires: (1) route table entry sending `0.0.0.0/0` traffic to
the NAT Gateway, (2) standard security group outbound rule allowing
443/80 — nothing application/command-specific.

---

## 8. Load Balancers

**Problem:** one server can't handle unlimited traffic, and is a single
point of failure if it goes down.

**Answer:** run multiple identical app servers, put a load balancer in front
to distribute traffic and detect failures.

```
                ┌──→ Server 1
Request ──→ LB ──→ Server 2
                └──→ Server 3
```

**Health checks — the actual failure-detection mechanism:**

- **L4 health check** — just attempts a TCP handshake on a port. Can give a
  **false healthy signal** if the app is frozen but the OS network stack
  still responds.
- **L7 health check** — sends a real HTTP request to a health endpoint
  (e.g. `/health`) and verifies the actual application response (status
  code, body, timeout). This is what correctly catches a frozen-but-running
  process, since the application itself never responds even if the port is
  technically open.

```
Every N seconds: LB sends health check to each instance
Fails M consecutive checks → marked UNHEALTHY → LB stops routing traffic there
Passes checks again → marked HEALTHY → traffic resumes
```

---

## 9. TLS/SSL

**Problem:** unencrypted data in transit can be read by anyone intercepting
it (ISP, attacker on public wifi, etc).

**Answer:** TLS encrypts the connection so only sender/receiver can read the
data, even if intercepted.

```bash
curl -v https://github.com 2>&1 | grep -i "ssl\|tls"
```

**Simplified handshake:**
```
1. Browser requests secure connection
2. Server sends certificate (proves identity, signed by a trusted CA)
3. Browser + server agree on encryption keys
4. All further data is encrypted
```

**Why certs can't be faked:** they're cryptographically signed by trusted
Certificate Authorities using a private key the attacker doesn't possess —
forging a valid cert without that key is computationally infeasible.

---

## 10. Debug Tools — curl & tcpdump

```bash
curl -I https://site.com           # headers only, quick health check
curl -v https://site.com           # full handshake detail
curl -X POST url -d "data"          # send POST request
curl -A "MyApp/1.0" url              # set custom User-Agent
```

```bash
sudo tcpdump -i any port 443 -c 5    # capture raw packets on a port
sudo tcpdump -i any host github.com -c 20   # filter to a specific host
```

**Why both, not just one:** `curl` shows the result from the application's
perspective (status code, success/fail). `tcpdump` shows the actual network
conversation — did the packet even leave the machine, was the connection
refused at the TCP level before HTTP was ever involved. Invaluable when the
problem is network-level, not application-level.

**Lesson learned hands-on:** ran `tcpdump` in background before `curl` —
captured unrelated background HTTPS traffic instead of the intended request,
since `-c 5` exhausted the capture before curl even started. Fix: filter by
`host`, and add a short `sleep` before firing the request being tested.

**TCP teardown flags observed in a real capture:**
```
P.  → PUSH+ACK (sending data, acknowledging previous)
FP. → FIN+PUSH+ACK ("done sending, here's my last data, ack yours")
.   → ACK only
F.  → FIN+ACK (other side also closing)
```
Same graceful-vs-abrupt philosophy as `kill` vs `kill -9` from Day 1 — a
clean FIN handshake vs an abrupt RST.

---

## 11. User-Agent Header

Self-reported string identifying the client (browser/bot/script) making a
request. Used for serving different content (mobile vs desktop), bot
identification (Googlebot), and API client tracking.

```bash
curl -A "MyApp/1.0" https://api.example.com
```

**Critical security lesson:** User-Agent is entirely self-reported and
trivially fakeable (`curl -A "Googlebot/2.1" ...`) — never trust it alone for
security/access-control decisions. Real anti-bot systems combine it with
other signals (request patterns, IP reputation, JS challenges).

---

## 12. Mock Interview — Self Corrections (Day 2)

1. **Layer placement:** ports belong to Transport layer (L4), not
   Application layer. Don't conflate "is the app responding" (L7) with "is
   the port open" (L4) — different layers, different failure modes.

2. **TCP reliability ≠ just the handshake.** The handshake only establishes
   the connection; ongoing reliability comes from per-packet ACK +
   retransmission-on-timeout + ordering + congestion control.

3. **Subnetting bit-count must be recalculated every time** based on how
   many subnets THIS question needs — don't carry over the borrowed-bit
   count from a previous example.

4. **NAT Gateway doesn't "convert" a private instance into public.** The
   instance stays private the entire time; the NAT Gateway is a separate
   resource in a public subnet that traffic routes *through*. Security
   groups operate at IP/port level only — no such thing as a rule scoped to
   a specific command like `apt upgrade`.

5. **L4 vs L7 health checks** — correctly identified both exist, refined to:
   L4 only proves the port accepts a TCP handshake (can false-positive on a
   frozen app); L7 proves the actual application logic responds correctly.

**Self-rating: 7/10** — improvement over Day 1. Connecting concepts across
topics more naturally now (OSI layers ↔ L4/L7 health checks) without being
walked through each in isolation. Remaining gap is the same pattern as
Day 1: correct on the "what/why," needs more precision on exact mechanism
under interview pressure.

---

## Status: Networking For DevOps — Complete
Next: Shell Scripting Fundamentals + Automation Scripts
