# Day 13 — Azure DevOps Basics & CI Concepts

Light orientation session today — touching the fundamentals of CI and
Azure DevOps before a dedicated deeper session later in the roadmap.

---

## 1. What is CI — First Principles

**Problem:** multiple developers push code to the same repository
simultaneously. Without automation, broken code can silently merge into
the main branch, breaking the entire application for everyone — and the
longer it sits undetected, the harder and more expensive it is to fix.

**Answer:** Continuous Integration (CI) — an automated process that runs
every time code is pushed or a pull request is raised, verifying the code
is valid before it's allowed to merge.

```
Developer pushes code / raises PR
          ↓
CI pipeline triggers automatically
          ↓
Build the code (compile, package)
          ↓
Run automated tests
          ↓
Pass → code can be merged ✅
Fail → developer is notified, merge is blocked ❌
```

**Core principle:** catch problems at the source, when they're cheap to
fix, instead of discovering them after they've already reached production.

---

## 2. Build on Pull Request vs Build on Merge

**Build on Pull Request (PR):**
Triggered when a developer opens or updates a PR — before the code is
merged. This is the safety gate — the merge is blocked if the build or
tests fail. Most common and most important trigger in real teams.

**Build on Merge:**
Triggered after code is merged into the main branch. Often used for
deployment pipelines (CD — Continuous Deployment) — "now that this code
is confirmed merged and stable, deploy it to the environment."

```
PR raised → CI runs → tests pass → PR merged → CD runs → deploys to staging/prod
```

---

## 3. Azure DevOps — What It Is

Microsoft's end-to-end DevOps platform, bringing multiple tools under
one roof:

```
Azure Repos      → Git repositories (like GitHub, hosted on Azure)
Azure Pipelines  → CI/CD pipelines (build, test, deploy automation)
Azure Boards     → project management, work items, sprints (like Jira)
Azure Artifacts  → package registry (npm, pip, Maven packages)
Azure Test Plans → manual and automated test management
```

Not all of these need to be used together — Azure Pipelines is commonly
used standalone with GitHub repos, for example. The platform is modular.

---

## 4. Azure DevOps vs GitHub Actions

Since the roadmap includes GitHub Actions as a dedicated session later,
worth noting the distinction upfront:

```
Azure DevOps Pipelines → Microsoft's older, more enterprise-focused CI/CD
                         YAML-based pipelines, deep Azure integration
                         Better for large enterprise teams already in the
                         Microsoft ecosystem

GitHub Actions         → newer, simpler, community-driven
                         Event-driven workflows triggered by GitHub events
                         Massive marketplace of community actions
                         Better for open-source and modern DevOps workflows
```

Both ultimately do the same job — automate build, test, and deploy on
code changes. GitHub Actions is the more commonly listed skill in job
postings currently, including Dubai market.

---

## 5. Where This Fits in the Roadmap

CI/CD is not a standalone concept — it connects everything you've already
built:

```
Git (Day 4)       → the trigger: every push/PR starts the pipeline
Docker (Day 5)    → the build artifact: CI builds and pushes a Docker image
Azure (Days 7-12) → the deployment target: CD deploys to Azure VMs/AKS
Terraform (next)  → infrastructure provisioned by the pipeline itself
Kubernetes (AKS)  → the runtime the CD pipeline deploys containers into
```

A complete CI/CD pipeline for a real project will tie all of these
together — that's the capstone project direction once the remaining
modules are covered.

---

## Status: CI/CD — Basic orientation complete
Dedicated CI/CD session (GitHub Actions, pipeline setup, real deployment)
coming after Terraform and Kubernetes modules.

Note: Day 12 (Azure IAM — Users, Groups, Roles, Service Principals,
Managed Identities) MD file still pending — parked temporarily,
to be written before Terraform since IAM concepts are prerequisites
for Terraform authentication to Azure.
