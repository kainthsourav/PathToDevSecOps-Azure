Terraform Backend & Infra RBAC Setup
🎯 Goal
Use least privilege for GitHub Actions Service Principal when running Terraform:

Backend RG (rg-terraform-state) → only access to Terraform state storage.

Infra RG (rg-dotnet-k8s-demo) → full Contributor rights to manage AKS, ACR, etc.

🔑 Role Assignments
Backend RG (Terraform State)
Terraform needs to:

Read Storage Account metadata (Microsoft.Storage/storageAccounts/read)

Read/write blobs (state file)

Assign:

bash
# Reader (to read Storage Account properties)
az role assignment create --assignee <SP_APP_ID> --role Reader --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-terraform-state

# Storage Blob Data Contributor (to read/write state blobs)
az role assignment create --assignee <SP_APP_ID> --role "Storage Blob Data Contributor" --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-terraform-state
Infra RG (AKS, ACR, etc.)
Terraform needs to create/update/delete infra resources.

Assign:

bash
az role assignment create --assignee <SP_APP_ID> --role Contributor --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-dotnet-k8s-demo
📋 Verification
Check current roles:

bash
az role assignment list --assignee <SP_APP_ID> -o table
Expected:

Reader → scope: rg-terraform-state

Storage Blob Data Contributor → scope: rg-terraform-state

Contributor → scope: rg-dotnet-k8s-demo

🛡️ Why This Matters
Backend RG: locked down, only blob + read access.

Infra RG: full Contributor, but only where infra is deployed.

Prevents accidental deletion or modification of backend resources.

Enforces enterprise‑grade least privilege.