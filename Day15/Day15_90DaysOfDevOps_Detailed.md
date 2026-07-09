# Day 14 -- CI Complete, CD Blocked (For Now)

## Overview

Today I completed the Continuous Integration (CI) portion of my Azure
DevOps pipeline for Docker's multi-service voting application. While I
planned to finish the Continuous Deployment (CD) workflow as well, an
Azure Student subscription limitation prevented me from provisioning an
AKS cluster.

Even though the deployment wasn't completed, the CI pipeline is fully
functional and production-style.

------------------------------------------------------------------------

## What I Built

The CI pipeline performs the following steps automatically whenever code
is pushed to the repository:

1.  Detects changes in the Git repository.
2.  Starts an Azure DevOps pipeline.
3.  Builds a new Docker image.
4.  Pushes the image to Azure Container Registry (ACR).
5.  Updates the Kubernetes deployment manifest with the newly generated
    image tag using a shell script.
6.  Commits the manifest change back to the repository.

This creates a complete automated build workflow with no manual image
management.

------------------------------------------------------------------------

## Planned GitOps Workflow

The intended CD architecture was:

``` text
Developer Push
      │
Azure DevOps Pipeline
      │
Build Docker Image
      │
Push to ACR
      │
Update Kubernetes Manifest in Git
      │
ArgoCD Watches Repository
      │
AKS Cluster Detects Change
      │
Application Automatically Updated
```

This follows the GitOps model where Git acts as the single source of
truth and ArgoCD continuously reconciles the Kubernetes cluster with the
repository state.

------------------------------------------------------------------------

## Roadblock

Creating an Azure Kubernetes Service (AKS) cluster failed because of
quota/availability limitations on the Azure Student subscription.

Rather than spending hours fighting infrastructure limits, I decided to
move forward with other production-focused topics and revisit AKS later.

------------------------------------------------------------------------

## Next Topic

Azure Key Vault

Before deploying production applications, secrets such as passwords, API
keys, certificates, and connection strings should never be stored inside
source code or Kubernetes manifests.

Learning Azure Key Vault now fits naturally into the CI/CD journey.

------------------------------------------------------------------------

## Key Learnings

-   Automated Docker image builds using Azure Pipelines.
-   Pushing images securely to Azure Container Registry.
-   Updating Kubernetes manifests automatically.
-   Understanding GitOps workflows with ArgoCD.
-   Real-world cloud projects often involve subscription and quota
    limitations.
-   Adapting the learning path is sometimes better than waiting on
    blocked infrastructure.

------------------------------------------------------------------------

## Status

-   ✅ CI Pipeline Complete
-   ⏳ CD Pipeline Pending (AKS)
-   🚀 Next: Azure Key Vault

**Day 14/90 -- 90 Days of DevOps**
