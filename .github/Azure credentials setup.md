# Setting Up `AZURE_CREDENTIALS` in GitHub Actions

**Topic:** Secure Azure authentication for CI/CD pipelines  
**Skill level:** Intermediate  
**Applies to:** GitHub Actions + Azure DevOps pipelines

---

## What Is `${{ secrets.AZURE_CREDENTIALS }}`?

When a GitHub Actions pipeline needs to interact with Azure (push a Docker image, deploy to AKS, run Terraform), it must **authenticate with Azure** first.

`${{ secrets.AZURE_CREDENTIALS }}` is a GitHub Secret that stores a JSON block containing your **Azure Service Principal (SP)** credentials. The pipeline reads this secret and uses the `azure/login@v1` action to establish an authenticated session — without ever exposing passwords in your workflow YAML.

**Why this matters in enterprise:**
- No hardcoded credentials in code or config files
- Access is scoped to a specific resource group (least-privilege principle)
- Service Principal can be rotated or revoked without touching the pipeline

---

## Step 1 — Create a Service Principal

Run this command in Azure CLI (PowerShell or Bash):

```powershell
az ad sp create-for-rbac `
  --name "github-actions-sp" `
  --role contributor `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-dotnet-k8s-demo `
  --sdk-auth
```

**What each flag does:**

| Flag | Purpose |
|---|---|
| `--name` | Friendly name for the Service Principal in Azure AD |
| `--role contributor` | Grants rights to create/update/delete resources |
| `--scopes` | Limits access to just your resource group (best practice) |
| `--sdk-auth` | Outputs JSON in the exact format GitHub Actions expects |

> **Security tip:** Always scope to a specific resource group, not the whole subscription. This follows the principle of least privilege.

---

## Step 2 — Copy the JSON Output

After running the command, Azure prints a JSON block like this:

```json
{
  "clientId": "xxxx-xxxx-xxxx",
  "clientSecret": "xxxx-xxxx-xxxx",
  "subscriptionId": "xxxx-xxxx-xxxx",
  "tenantId": "xxxx-xxxx-xxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

**Copy this entire JSON block.** You will paste it as a GitHub Secret in the next step.

> **Important:** Treat `clientSecret` like a password. Do not commit this JSON to source control.

---

## Step 3 — Add as a GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret**
4. Set the name to exactly: `AZURE_CREDENTIALS`
5. Paste the full JSON from Step 2 as the value
6. Click **Add secret**

The secret is now encrypted and stored by GitHub. Only Actions workflows in this repo can access it.

---

## Step 4 — Use It in Your Workflow YAML

Add this step at the start of any job that needs Azure access:

```yaml
- name: Login to Azure
  uses: azure/login@v1
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**What happens under the hood:**
1. GitHub decrypts the secret and passes the JSON to the `azure/login` action
2. The action authenticates with Azure AD using the Service Principal
3. An access token is stored in the runner's environment
4. All subsequent steps (Terraform, Docker push to ACR, kubectl apply, etc.) use this token automatically

---

## Full Example — CI/CD Pipeline Using `AZURE_CREDENTIALS`

```yaml
name: Deploy to AKS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to Azure
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login to Azure Container Registry
        run: az acr login --name myRegistry

      - name: Build and push Docker image
        run: |
          docker build -t myregistry.azurecr.io/demoapi:${{ github.sha }} .
          docker push myregistry.azurecr.io/demoapi:${{ github.sha }}

      - name: Set AKS context
        uses: azure/aks-set-context@v3
        with:
          resource-group: rg-dotnet-k8s-demo
          cluster-name: my-aks-cluster

      - name: Deploy to AKS
        run: kubectl apply -f k8s/deployment.yaml
```

---

## Common Errors and Fixes

| Error | Likely Cause | Fix |
|---|---|---|
| `AADSTS700016: Application not found` | Wrong `clientId` in the JSON | Recreate the Service Principal and copy fresh JSON |
| `AuthorizationFailed` | SP doesn't have access to the resource group | Check `--scopes` in the `az ad sp create-for-rbac` command |
| `Secret not found` | Wrong secret name in workflow | Ensure the secret is named exactly `AZURE_CREDENTIALS` (case-sensitive) |
| `The provided JSON is invalid` | JSON was partially copied | Copy the full JSON block including all fields |

---

## Key Concepts Summary

| Concept | What It Is |
|---|---|
| **Service Principal** | An identity (like a user account) for apps/pipelines to authenticate with Azure |
| **Client ID** | The "username" of the Service Principal |
| **Client Secret** | The "password" of the Service Principal |
| **Tenant ID** | Your Azure Active Directory (organisation) identifier |
| **Contributor role** | Azure RBAC role allowing create/update/delete on resources |
| **`--sdk-auth`** | Flag that formats the SP output for use with Azure SDKs and GitHub Actions |

---

## Related Topics

- **Azure Managed Identity** — alternative to Service Principals for resources hosted inside Azure (no secrets needed)
- **OpenID Connect (OIDC)** — more secure alternative to `AZURE_CREDENTIALS` using short-lived tokens (no client secret stored)
- **Azure Key Vault** — storing application secrets separately from pipeline credentials
- **RBAC (Role-Based Access Control)** — controlling what the Service Principal can and cannot do

---

*Last updated: 2026 | Part of: DevOps Learning Series*