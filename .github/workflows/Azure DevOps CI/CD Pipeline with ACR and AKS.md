Azure DevOps CI/CD Pipeline with ACR and AKS

This document summarizes the full setup we walked through for building, pushing, and deploying a .NET 8 Web API (DemoApi) using GitHub Actions, Azure Container Registry (ACR), and Azure Kubernetes Service (AKS).

1. Azure Resource Setup

Resource Group: Logical container for resources.

az group create --name rg-dotnet-k8s-demo --location eastasia

Azure Container Registry (ACR): Private Docker registry.

az acr create --resource-group rg-dotnet-k8s-demo --name acrdemosourav --sku Basic

2. Service Principal & GitHub Secrets

Create Service Principal:

az ad sp create-for-rbac \
  --name "github-actions-sp" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-dotnet-k8s-demo \
  --sdk-auth

Copy JSON output and add to GitHub Secrets as AZURE_CREDENTIALS.

Extract clientId and clientSecret from JSON and add as secrets:

AZURE_CLIENT_ID

AZURE_CLIENT_SECRET

Add ACR_NAME secret with your registry name (e.g., acrdemosourav).

3. Role Assignment for ACR

Ensure Service Principal has AcrPush role:

az role assignment create \
  --assignee <APP_ID> \
  --role AcrPush \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-dotnet-k8s-demo/providers/Microsoft.ContainerRegistry/registries/acrdemosourav

4. GitHub Actions Workflow

Example Hybrid Workflow (Build + Push, then Deploy)

name: Build and Publish

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - uses: actions/checkout@v2

      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login to ACR
        run: az acr login --name ${{ secrets.ACR_NAME }}

      - name: Build Docker image
        run: docker build -f docker/DemoApi.Dockerfile -t demoapi:latest .

      - name: Tag Docker image
        run: docker tag demoapi:latest ${{ secrets.ACR_NAME }}.azurecr.io/demoapi:${{ github.sha }}

      - name: Push Docker image
        run: docker push ${{ secrets.ACR_NAME }}.azurecr.io/demoapi:${{ github.sha }}

  deploy:
    runs-on: ubuntu-latest
    needs: build-and-push
    environment: prod   # approval gate can be configured here
    steps:
      - name: Deploy to AKS
        uses: azure/aks-deploy@v1
        with:
          resource-group: rg-dotnet-k8s-demo
          name: aks-dotnet-demo
          images: ${{ secrets.ACR_NAME }}.azurecr.io/demoapi:${{ github.sha }}
          manifests: |
            k8s/deployment.yaml
            k8s/service.yaml

5. Environment-Specific Secrets

Define environments in GitHub (dev, staging, prod).

Add secrets per environment:

AZURE_CREDENTIALS

AZURE_CLIENT_ID

AZURE_CLIENT_SECRET

ACR_NAME

Workflow automatically picks the right secrets based on environment:.

6. Common Errors & Fixes

Missing build context → Add . at end of docker build.

Unauthorized push → Ensure AcrPush role assigned and run az acr login.

Too many jobs/runners → Use hybrid workflow (combine build+push, separate deploy).

7. Best Practices

Use GitHub Environments for dev/staging/prod with approval gates.

Tag images with ${{ github.sha }} for uniqueness.

Scope Service Principal permissions narrowly (least privilege).

Keep secrets in GitHub, not hardcoded in YAML.

✅ With this setup:

Code pushed to main → GitHub Actions builds Docker image → pushes to ACR → deploys to AKS.

Secure, environment-aware, and interview-ready pipeline.