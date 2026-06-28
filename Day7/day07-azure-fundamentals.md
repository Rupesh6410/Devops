# Day 7 — Azure Cloud Fundamentals

Switched cloud provider focus from AWS to Azure, since AWS overhauled its
free tier in mid-2025 (new accounts now get a $200 credit pool expiring in
6 months, instead of the old 12-month free usage model) and existing
credits had already been used up. Azure terminology will be used going
forward; AWS-equivalent terms are noted throughout, since Dubai job postings
still frequently reference AWS specifically.

---

## 1. IaaS vs PaaS vs SaaS — Where Responsibility Actually Shifts

**The real distinction that matters (not just naming the three letters):**
each model moves the line of "what you manage" vs "what the provider
manages" further up the stack.

```
IaaS (Infrastructure as a Service)
  → You manage: OS, runtime, app, data
  → Provider manages: physical hardware, virtualization, networking
  → Azure example: Virtual Machines (VMs)
  → AWS equivalent: EC2

PaaS (Platform as a Service)
  → You manage: just the application code and data
  → Provider manages: OS, runtime, patching, scaling infrastructure
  → Azure example: Azure App Service
  → AWS equivalent: Elastic Beanstalk

SaaS (Software as a Service)
  → You manage: nothing - just a USER of fully managed software
  → Provider manages: everything
  → Example: Microsoft 365, Gmail
```

**Why this matters practically:** choosing IaaS vs PaaS for a project is a
real architectural decision — IaaS gives full control (needed for custom
configs, specific compliance needs) at the cost of managing more yourself;
PaaS trades that control for speed and less operational overhead.

---

## 2. Virtualization — The Foundation Underneath All of This

**Problem:** physical servers are expensive and inefficient to dedicate
one-per-customer/application — most of a single physical machine's capacity
would sit idle.

**Answer:** a hypervisor divides one physical machine into multiple
isolated virtual machines, each behaving like its own independent computer
with its own OS, while actually sharing the same underlying physical
hardware.

This is the literal mechanism that makes cloud computing economically
possible at scale — one physical server can host many customers' VMs
simultaneously, each isolated from the others.

---

## 3. Load Balancers — Same Concept, Azure Context

Already covered conceptually in Networking (Day 2) — same core idea:
distribute incoming traffic across multiple VM instances so no single
instance is a point of failure, with health checks detecting and routing
around unhealthy instances automatically.

```
Azure Load Balancer / Application Gateway  ↔  AWS ALB/NLB
```

Same L4 vs L7 distinction applies: a basic load balancer checks at the
connection level, while an Application Gateway (Azure's L7 option) can
inspect actual HTTP requests — same frozen-process gotcha from the Day 2
mock interview applies here too.

---

## 4. Availability Zones vs Regions

**Region:** a specific geographic area where Azure has a cluster of data
centers (e.g., "East US," "UK South").

**Availability Zone (AZ):** physically separate locations WITHIN a region,
each with independent power, cooling, and networking.

```
Region: East US
  ├── Availability Zone 1
  ├── Availability Zone 2
  └── Availability Zone 3
```

**Why this matters (same reasoning as the AWS subnetting lesson from
earlier):** spreading infrastructure across multiple AZs protects against a
single data center failure (power outage, hardware failure) — if AZ1 goes
down, resources in AZ2/AZ3 keep running. Spreading across Regions protects
against a much larger-scale event affecting an entire geographic area.

Direct connection to earlier subnetting work: this is the same reason a
production subnet layout splits public/private tiers across multiple AZs,
not just multiple subnets in one AZ.

---

## 5. Disaster Recovery — Backup vs Actual Recovery Plan

**Key distinction:** having a backup is NOT the same as having a disaster
recovery plan.

A backup is just a copy of data. A disaster recovery plan defines:
- **RTO (Recovery Time Objective):** how long can the system be down before
  it must be restored?
- **RPO (Recovery Point Objective):** how much data loss (measured in time)
  is acceptable if a failure happens right now?

**Why this distinction matters practically:** a company can have perfect
backups but still suffer a major incident if nobody has defined or tested
how long restoring from those backups actually takes, or whether the
restored data is recent enough to be useful.

---

## Status: Azure Fundamentals — Core Concepts Introduced
Next: Azure hands-on (VMs, VNets, Storage) — Terraform — Kubernetes (AKS)

Note: Docker 3-tier app + industry-grade practices session (originally
planned as the session immediately following Docker fundamentals) is still
pending and will be slotted in/backfilled relative to this day.
