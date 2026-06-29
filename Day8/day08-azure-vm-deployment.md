# Day 8 — Azure VM Deployment (Hands-On)

Moved from Azure theory into actually deploying and serving something real.
Hit several genuine real-world constraints along the way — documented as
they happened, since debugging these taught more than a tutorial that just
works on the first try would have.

---

## 1. Azure for Students — Real Subscription Constraints

Tried to create a `Standard_D2s_v3` VM (2 vCPU, 8 GiB) and got:
```
This size is currently unavailable in eastus for this subscription: NotAvailableForSubscription
```

**Root cause:** `Standard_D2s_v3` is a general-purpose paid SKU, not a
free-tier/student-eligible size. Azure for Students subscriptions:
- Operate at the lowest priority tier for regional compute capacity
- Are restricted to a specific, limited set of allowed regions (varies per
  student) — checked via Policy → Assignments → "Allowed resource
  deployment regions." Mine: `austriaeast`, `uaenorth`, `centralindia`,
  `koreacentral`, `southeastasia`
- Are restricted to specific VM families — mainly **B-series**
  (`Standard_B1s`, `Standard_B2s`) — burstable, lower baseline performance,
  intended for learning/light workloads
- This is a deliberate policy restriction on the sponsored offer type, not
  something fixable by editing/deleting the policy myself — same
  least-privilege principle as IAM/security groups, just applied at the
  subscription level to prevent free-tier misuse

**Fix:** searched specifically for `Standard_B1s`/`Standard_B2s` instead of
browsing the default size list, picked an allowed region (`centralindia`),
and confirmed Security Type was set to "Standard" rather than "Trusted
launch" (newer VM sizes don't all support Trusted launch's vTPM/Secure Boot
requirements, which can silently filter sizes out of the list).

**Note for later:** `uaenorth` is Azure's actual UAE/Dubai region — worth
deliberately using this region for future portfolio projects specifically,
given the Dubai job-market target.

---

## 2. Connecting via SSH — Key Permissions

Downloaded the `.pem` private key during VM creation.

```bash
chmod 600 ~/Downloads/newvm_key.pem
```

**Why this is mandatory:** SSH refuses to use a key with overly open
permissions (readable/writable by group or others) — a private key
readable by other users on the system would be a security hole. `600`
(read+write owner only) or `400` (read-only owner only) both satisfy this;
SSH only cares that group/others have zero access.

```bash
ssh -i ~/Downloads/newvm_key.pem azureuser@<VM_PUBLIC_IP>
```

This is the exact public-key authentication mechanism from the Networking
module (Day 2) — the VM holds the matching public key (placed there by
Azure at creation), the `.pem` file is the private key, and SSH verifies
identity without the private key ever being transmitted.

**Better practice going forward:** move keys out of `~/Downloads` into
`~/.ssh/` — the conventional, expected location, less likely to be
accidentally deleted/moved.

---

## 3. Installing & Verifying nginx

Same exact commands/habits as local Ubuntu practice — confirms that once
SSH'd in, it's just operating on another Linux machine, same mental model:

```bash
sudo apt update
sudo apt install nginx -y
sudo systemctl status nginx      # active (running)
curl http://localhost              # confirms response FROM INSIDE the VM
```

---

## 4. The Real Constraint — NSG Blocking External Access

```bash
curl http://<VM_PUBLIC_IP>
```
Worked from inside the VM, but did NOT work when tried from outside
(local machine / browser) on the first attempt.

**Root cause:** Azure VMs have a **Network Security Group (NSG)** —
Azure's equivalent of AWS Security Groups — controlling inbound traffic.
A new VM by default typically only allows inbound on port 22 (SSH), not
port 80 (HTTP), since Azure doesn't assume a web server is intended.

**Fix:**
```bash
az vm open-port --port 80 --resource-group my-rg --name newvm
```
(or via Portal: VM → Networking → NSG → Inbound port rules → Add rule,
allow TCP port 80)

```bash
curl http://<VM_PUBLIC_IP>      # now works, tested from local machine
```

**The lesson, precisely:** the VM/service itself was completely healthy
(nginx running, port listening locally) — but a separate network layer
(NSG) sat in front and blocked traffic. Exactly the kind of "which layer is
actually broken" diagnostic thinking from the OSI model lessons (Day 2) —
verified by checking from inside (service health) vs outside (network
layer) separately rather than assuming one check covers both.

**Tool note:** `ping` cannot check a specific port — ICMP (what ping uses)
operates at Layer 3 and has no concept of ports at all (ports are a Layer 4
TCP/UDP concept). The correct tool for "is this specific port reachable" is
`nc -zv <ip> <port>` or `curl`, not `ping`.

---

## 5. Serving a Custom Website

nginx serves files from `/var/www/html/` by default — confirmed by reading
the default `index.html` there before replacing it.

```bash
sudo nano /var/www/html/index.html
```
Replaced with custom HTML, then:
```bash
curl http://localhost
curl http://<VM_PUBLIC_IP>
```
Confirmed custom content live, reachable from a browser via the public IP.

**More production-realistic approach (also done):** created a separate
directory (`/var/www/my-devops-journey/`), pointed nginx's config
(`/etc/nginx/sites-available/default`, the `root` directive) at it instead
of editing the default folder directly.

```bash
sudo nginx -t                      # test config syntax BEFORE applying
sudo systemctl reload nginx         # reload (not restart) - re-reads config without dropping active connections
```

`nginx -t` before reload is the same defensive habit as testing `sed`
without `-i` first, or testing `/etc/fstab` with `mount -a` before
rebooting — catch config mistakes before they take down a live service.

```bash
sudo tail -f /var/log/nginx/access.log
```
Watched real requests arrive live while hitting the public IP from a
browser — same exercise as Day 1, now happening on real cloud
infrastructure with a real public IP instead of localhost.

---

## 6. Azure Resource Manager (ARM) & Resource Groups

**Problem:** every resource created (VM, its NSG, its public IP, its disk)
needs to be organized and tracked together as a logical unit.

**Answer:** Resource Groups — logical containers holding related
resources — managed underneath by Azure Resource Manager (ARM), the layer
that actually processes every create/update/delete request, regardless of
whether it comes from the Portal, the CLI, or Terraform later.

```bash
az group list --output table
az resource list --resource-group my-rg --output table
```

**Key realization:** creating "one VM" through the portal wizard actually
silently created MULTIPLE separate resources — network interface, public
IP, NSG, disk — all grouped into one Resource Group. This is exactly why a
single `az group delete` can clean up everything at once later, instead of
hunting down and deleting each piece manually.

**Why this matters for what's coming next:** Terraform doesn't talk to
Azure resources directly — it talks to ARM, the same management layer
touched today via the `az` CLI. Understanding "everything goes through
Resource Manager" now means Terraform's behavior later won't feel like new
magic — it's the same underlying API, just declared as code instead of
clicked through a portal or typed via CLI.

---

## Status: Azure VM Deployment, Hands-On — Complete
Next: More Azure (Storage, VNets hands-on) → Terraform → Kubernetes (AKS)
