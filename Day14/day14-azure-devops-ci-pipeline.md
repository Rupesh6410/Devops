# Day 14 — Azure DevOps CI Pipeline: Multi-Service Voting App

Most complete hands-on CI session so far. Built a full CI pipeline for a
real multi-service application — Docker's example voting app — on Azure
DevOps, end to end, with separate pipelines per microservice, a self-hosted
agent on an Azure VM, and an Azure Container Registry for built images.

---

## 1. The Application — Docker Example Voting App

A real multi-service application with genuinely separate, independent
services:

```
vote/     → Python web app (user submits a vote)
result/   → Node.js web app (displays vote results)
worker/   → .NET service (reads from Redis, writes to Postgres)
redis/    → message queue between vote and worker
db/       → PostgreSQL database
```

Each service has its own `Dockerfile`, its own build context, its own
independent release cycle — a real microservices architecture, not a
monolith with a single build. This is exactly why separate pipelines per
service make sense here, not one pipeline for everything.

---

## 2. Migrating from GitHub to Azure Repos

**Why import into Azure Repos rather than just connecting Pipelines to GitHub:**
Keeping source code in Azure Repos means the entire DevOps workflow
(code, pipelines, boards, artifacts) lives within one platform — simpler
access control, unified audit trail, no dependency on an external service.

```
GitHub repo → Import → Azure Repos
(docker/example-voting-app)  (Azure DevOps project)
```

After import, Azure Repos becomes the source of truth — all subsequent
commits, branches, and PRs happen there, not on GitHub.

---

## 3. Self-Hosted Agent on Azure VM

**Why self-hosted instead of Microsoft-hosted agents:**

```
Microsoft-hosted agent:
  ✅ Zero setup, always clean environment
  ❌ No persistent state/caching between runs
  ❌ Limited customization
  ❌ Costs pipeline minutes from quota
  ❌ No access to private VNet resources

Self-hosted agent (on Azure VM, Linux):
  ✅ Full control over installed tools and environment
  ✅ Persistent tool/dependency caching between runs (faster builds)
  ✅ Access to private VNet (can deploy to private resources)
  ✅ No per-minute cost beyond the VM itself
  ❌ You manage the VM, updates, and agent health
```

**Setup process:**
1. Created a Linux Azure VM (same region as the project)
2. In Azure DevOps: Project Settings → Agent Pools → New Pool → Self-hosted
3. Generated a PAT (Personal Access Token) for agent authentication
4. On the VM: downloaded the Azure Pipelines agent, configured with PAT and organization URL, registered with the pool, ran as a service so it persists across VM reboots

```bash
# On the Azure VM:
mkdir myagent && cd myagent
tar zxvf vsts-agent-linux-x64-*.tar.gz
./config.sh --url https://dev.azure.com/your-org --auth pat --token <PAT>
sudo ./svc.sh install
sudo ./svc.sh start
```

Agent appeared as online in Azure DevOps → Agent Pools after registration.

---

## 4. Azure Container Registry (ACR)

Created a dedicated ACR to store built Docker images — private, integrated
with Azure DevOps, no Docker Hub dependency.

```
AWS equivalent: ECR (Elastic Container Registry)
```

**Why ACR over Docker Hub for this setup:**
- Private by default — images not publicly visible
- Native Azure RBAC integration — control who can push/pull
- Same Azure region as the VMs/AKS that will eventually pull the images
  (lower latency, no egress costs for pulls within the same region)
- Integrates directly with Azure DevOps service connections

**Service connection created:** Azure DevOps → Project Settings → Service
Connections → Docker Registry → Azure Container Registry — this allows
pipelines to authenticate to ACR without storing credentials directly in
the YAML.

---

## 5. Separate Pipeline Per Microservice — Why and How

**Why separate pipelines, not one monolithic pipeline:**
```
One pipeline for everything:
  ❌ Changing one line in vote/ triggers a rebuild of result/ and worker/ too
  ❌ Slower — builds things that didn't change
  ❌ If worker/ build fails, it blocks vote/ deployment even though vote/ is fine
  ❌ No independent release cycles per service

Separate pipeline per service:
  ✅ Only the changed service rebuilds
  ✅ Each service deployable independently
  ✅ Failures isolated to the affected service
  ✅ Cleaner, more maintainable as the app grows
```

**Path-based triggers** — each pipeline only fires when files in its
specific directory change:

```yaml
# vote pipeline trigger
trigger:
  paths:
    include:
      - vote/*
```

A commit changing only `result/app.js` triggers only the result pipeline —
vote and worker pipelines are untouched.

---

## 6. Pipeline YAML — Structure for Each Microservice

Each pipeline followed the same pattern, parameterized per service:

```yaml
trigger:
  paths:
    include:
      - vote/*          # path-based: only trigger on changes in this directory

pool:
  name: self-hosted-pool  # use the self-hosted agent on the Azure VM

variables:
  imageName: 'vote-app'
  acrName: 'yourregistry.azurecr.io'

stages:
  - stage: Build
    jobs:
      - job: BuildAndPush
        steps:
          - task: Docker@2
            displayName: 'Build and Push to ACR'
            inputs:
              command: buildAndPush
              repository: $(acrName)/$(imageName)
              dockerfile: vote/Dockerfile
              containerRegistry: 'acr-service-connection'
              tags: |
                $(Build.BuildId)
                latest
```

**Breaking down key parts:**

`Docker@2 task` — Azure DevOps built-in task that handles `docker build`
and `docker push` using the service connection for ACR authentication —
no credentials needed in the YAML itself.

`$(Build.BuildId)` — a built-in Azure DevOps variable, unique per build
run — used as an image tag so every build produces a distinctly tagged
image, never overwriting a previous build's image (except `latest`).

`tags: $(Build.BuildId)` — tagging with the build ID directly connects
the running container back to the exact pipeline run that built it —
same principle as the Git commit hash tagging from Docker best practices
(Day 5).

---

## 7. Results — All Pipelines Green

All three service pipelines ran successfully:

```
vote pipeline    → built vote/ image → pushed to ACR ✅
result pipeline  → built result/ image → pushed to ACR ✅
worker pipeline  → built worker/ image → pushed to ACR ✅
```

Each image now lives in ACR tagged with its build ID, ready to be pulled
by a deployment pipeline or Kubernetes (AKS) in a future session.

---

## 8. Full Architecture of What Was Built Today

```
Azure Repos (imported from GitHub)
  ├── vote/
  │     └── triggers vote-pipeline on push
  ├── result/
  │     └── triggers result-pipeline on push
  └── worker/
        └── triggers worker-pipeline on push

Self-hosted Agent (Azure VM, Linux)
  └── executes all pipeline jobs

Azure Container Registry
  ├── yourregistry.azurecr.io/vote-app:latest + :BuildId
  ├── yourregistry.azurecr.io/result-app:latest + :BuildId
  └── yourregistry.azurecr.io/worker-app:latest + :BuildId
```

---

## 9. Connections to Previous Modules

```
Git (Day 4)       → Azure Repos is just Git, hosted on Azure — same
                    branching, commits, PRs, all familiar
Docker (Day 5)    → Dockerfiles, image building, tagging, pushing to
                    registry — all applied directly in the pipeline
Docker best practices (Day 5) → tagging with build ID instead of just
                    "latest" — same principle, now automated in CI
Azure VMs (Day 8) → self-hosted agent runs on the same kind of VM
                    deployed and managed the same way
Azure IAM (Day 12) → service connection uses a Service Principal under
                    the hood to authenticate pipeline to ACR
```

---

## Status: CI Pipeline (Azure DevOps) — Complete
Next: CD pipeline (deploying built images to AKS) → Terraform → Kubernetes
