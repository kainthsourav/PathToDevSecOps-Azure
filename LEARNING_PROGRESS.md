# DevSecOps Learning Progress
> Azure DevOps Engineer / Cyber Security DevOps — April 2026
> Repo: PathToDevSecOps-Azure

---

## How to Use This File

- **✅ Done** — concept understood, hands-on built, interview questions covered
- **🔄 In Progress** — currently learning
- **⏳ Next** — queued
- **📋 Planned** — on the roadmap

For each completed topic, the **Key Files** column points to exactly where in the repo you built it.
The **Interview Guide** column points to the section in `Azure DevSecOps Engineering.md`.

---

## Progress Overview

| # | Topic | Status | Key Files | Interview Guide |
|---|-------|--------|-----------|-----------------|
| 1 | Docker | ✅ Done | `docker/DemoApi.Dockerfile` | Section 1 |
| 2 | GitHub Actions CI/CD | ✅ Done | `.github/workflows/app.yml`, `infra.yml`, `security.yml` | Section 2 |
| 3 | Kubernetes on AKS | ✅ Done | `k8s/base/`, `k8s/overlays/` | Section 3 |
| 4 | Terraform | ✅ Done | `infra/modules/aks-acr/` | Section 4 |
| 5 | Terragrunt | ✅ Done | `infra/environments/`, `infra/terragrunt.hcl` | Section 5 |
| 6 | Image Promotion | ✅ Done | `.github/workflows/app.yml` (promote-* jobs) | Section 6 |
| 7 | Kustomize | ✅ Done | `k8s/overlays/dev|staging|prod/kustomization.yaml` | Section 7 |
| 8 | Azure Governance | ✅ Done | `.github/TerraformSetup.md`, `infra/modules/aks-acr/main.tf` | Section 8 |
| 9 | Real Troubleshooting | ✅ Done | Documented in `Azure DevSecOps Engineering.md` | Section 9 |
| 10 | Durable Functions | 🔄 In Progress | `src/DemoApi.Functions/` | — |
| 11 | DevSecOps Deep Dive | ⏳ Next | — | — |
| 12 | Observability | ⏳ Next | — | — |
| 13 | Azure Governance Deep Dive | 📋 Planned | — | — |
| 14 | GitOps (ArgoCD) | 📋 Planned | — | — |
| 15 | PR Plan Comments | 📋 Planned | — | — |

---

## ✅ 1. Docker
**Core idea:** Package the app and its runtime into a single portable image.

What you built:
- Multi-stage Dockerfile — SDK stage compiles, aspnet stage runs. Final image ~200MB with no compiler.
- Non-root user (`appuser`) — security hardening, matches `runAsNonRoot: true` in K8s.
- `--platform linux/amd64` — forces AMD64 for AKS compatibility regardless of build machine.

Key concepts to recall:
- Image vs Container — class vs object analogy
- Why `exec format error` happens and how `--platform` fixes it
- How AKS pulls from ACR without credentials — kubelet managed identity + AcrPull role

```
docker build -f docker/DemoApi.Dockerfile -t demoapi:local .
docker run -p 8080:80 demoapi:local
```

---

## ✅ 2. GitHub Actions CI/CD
**Core idea:** Automate build, scan, and deploy on every push to main.

What you built:
- `app.yml` — build image, Trivy scan, deploy dev, promote to staging, monitor ACR, deploy staging, promote to prod, monitor ACR, deploy prod
- `infra.yml` — Terragrunt apply across dev → staging → prod with `needs:` chaining
- `security.yml` — Gitleaks secret scan → SonarCloud code quality

Key concepts to recall:
- `needs:` — dependency chain, only run after previous job succeeds
- `environment:` — links to GitHub Environment, enables approval gates and scoped secrets
- `concurrency: cancel-in-progress: false` — queue runs, never cancel mid-deployment
- Repository vs environment-level secrets — same name, different values per env
- Split pipelines — `infra/**` triggers only `infra.yml`, `src/**` triggers only `app.yml`

**Latest addition:** `monitor-staging-acr` and `monitor-prod-acr` jobs — poll ACR manifest endpoint every 30s before deploying. Prevents `ImagePullBackOff` from deploying before `az acr import` fully propagates.

---

## ✅ 3. Kubernetes on AKS
**Core idea:** Declare desired state, Kubernetes makes it real and keeps it that way.

What you built:
- `k8s/base/deployment.yaml` — probes, resource limits, non-root security context, read-only filesystem, volume mounts for temp dirs
- `k8s/base/service.yaml` — LoadBalancer exposing port 80 → 8080
- `k8s/base/hpa.yaml` — scale 2–5 replicas at 50% CPU
- Kustomize overlays — per-environment replica count, ACR image, ASPNETCORE_ENVIRONMENT

Key concepts to recall:
- Liveness vs Readiness probe — liveness restarts, readiness removes from load balancer
- Resource requests vs limits — requests for scheduling, limits for enforcement (OOMKilled at 137)
- Rolling update — new pod must pass readiness before old pod is removed = zero downtime
- `ProgressDeadlineExceeded` — rollout timed out, old pods still running, investigate new pods

```bash
kubectl get pods
kubectl describe pod <name>
kubectl logs <pod> --previous
kubectl rollout undo deployment/demoapi-deployment
```

---

## ✅ 4. Terraform
**Core idea:** Declare infrastructure as code. Terraform compares desired vs actual and makes only the necessary changes.

What you built:
- `infra/modules/aks-acr/main.tf` — Resource Group, ACR (`admin_enabled = false`), AKS (OIDC enabled, SystemAssigned identity), AcrPull role assignment
- `infra/modules/aks-acr/variable.tf` — typed variable declarations
- `infra/modules/aks-acr/output.tf` — exports ACR login server, AKS name, kubeconfig (sensitive)

Key concepts to recall:
- `terraform init` → `validate` → `plan` → `apply` — always in this order
- Remote state in Azure Blob — shared, locked, keeps kubeconfig out of Git
- `prevent_destroy = true` — last line of defense against accidental deletion
- State lock hang — almost never permissions, always stale lease. Fix: `az storage blob lease break`
- Why `UAA` role needed separately from `Contributor` — `Microsoft.Authorization/roleAssignments/write`

---

## ✅ 5. Terragrunt
**Core idea:** Write Terraform once, reference it from lightweight per-environment files.

What you built:
- `infra/terragrunt.hcl` — root config, remote state with `path_relative_to_include()`, generates `backend.tf` and `provider.tf`
- `infra/environments/dev|staging|prod/terragrunt.hcl` — ~15 lines each, only values

Key concepts to recall:
- `find_in_parent_folders()` — walks up to find root config, no hardcoded paths
- `path_relative_to_include()` — auto-generates unique state key per environment
- `inputs {}` block → becomes `TF_VAR_` env vars → Terraform reads them automatically
- No `-var` flags needed in the pipeline
- `dependency {}` block — for when one module needs outputs from another (not needed in this repo — each env is self-contained)

---

## ✅ 6. Image Promotion
**Core idea:** Build once, tag with git SHA, promote the same immutable image through environments.

What you built in `app.yml`:
- Build → dev ACR with `${{ github.sha }}` as tag
- `az acr import` to copy dev → staging → prod (server-side, no bandwidth, SHA preserved)
- **Monitor jobs** — poll ACR manifest endpoint before each deploy step

Key concepts to recall:
- Why rebuild per environment is wrong — different base layers, different package versions
- `az acr import` vs docker pull+push — server-side copy, digest preserved, no Docker daemon needed
- Dev ACR as source of truth — every image ever built exists there, staging may not have all
- Rollback — import specific SHA from dev ACR directly to target env, bypass promotion chain

---

## ✅ 7. Kustomize
**Core idea:** Per-environment differences as patches on top of a shared base — no file modification, no templating language.

What you built:
- `k8s/base/` — common manifests for all environments
- `k8s/overlays/dev|staging|prod/kustomization.yaml` — replica count, env var, image tag per environment

Key concepts to recall:
- Base vs overlay — base is the default, overlay only contains differences
- `kustomize edit set image` — pipeline sets the exact ACR image + SHA tag before apply
- `kubectl apply -k .` — renders base + overlay in memory, never modifies source files
- Kustomize vs Helm — patch-based vs template-based, no new language to learn

---

## ✅ 8. Azure Governance
**Core idea:** Control who can do what (RBAC) and how resources must be configured (Policy).

What you built:
- Least privilege SP — Contributor on infra RG, UAA on infra RG, Contributor on state RG
- Resource tags on every resource — `environment`, `managed_by`, `project`

Key concepts to recall:
- RBAC vs Policy — RBAC = who can act, Policy = how resources must be configured
- Scope to smallest necessary — resource group, not subscription
- Principle of least privilege — if SP credentials leak, attacker limited to two RGs
- Why `managed_by = "terraform"` tag matters — tells team not to edit manually

---

## 🔄 10. Durable Functions
**Core idea:** Stateful, long-running workflows as plain C# code. Framework handles state persistence, retries, and coordination via Azure Storage.

What you are building:
- `src/DemoApi.Functions/SecurityScanOrchestrator.cs` — chains secret scan → image scan → code quality
- `src/DemoApi.Functions/AcrMonitorOrchestrator.cs` — polls ACR until image is pullable
- `src/DemoApi.Functions/Activities/` — one activity per scan type

The three function types — must know cold:

| Type | Trigger | Job | Can have side effects? |
|------|---------|-----|----------------------|
| Client | HTTP, queue, timer | Starts orchestration, returns instance ID | Yes |
| Orchestrator | `OrchestrationTrigger` | Coordinates steps, awaits activities | **No** — must be deterministic |
| Activity | `ActivityTrigger` | Does the real work | Yes |

The four patterns — must be able to explain with examples from your repo:

| Pattern | What it does | Your repo example |
|---------|-------------|-------------------|
| Function Chaining | Steps run in sequence, output flows forward | SecurityScanOrchestrator — secret → image → quality |
| Fan-Out / Fan-In | Many parallel tasks, wait for all | Scanning multiple images simultaneously |
| Human Interaction | Pause and wait for external event | Approval gate with 24h timeout |
| Monitor | Poll until condition met, then continue | AcrMonitorOrchestrator — poll every 30s |

The replay rule — one sentence:
> The orchestrator runs again from the top every time it resumes; use `context.CurrentUtcDateTime` not `DateTime.UtcNow`, and put all side effects in activities.

Concepts still to cover in this topic:
- [ ] Retry policies on activity calls — `new RetryOptions(TimeSpan.FromSeconds(5), 3)`
- [ ] Sub-orchestrations — orchestrator calling another orchestrator
- [ ] Eternal orchestrations — orchestrations that never end (monitoring loops that restart themselves)
- [ ] Durable entities — stateful actors, alternative to orchestrations for fine-grained state

---

## ⏳ 11. DevSecOps Deep Dive
**What this adds:** Formal security practices beyond what is already in the pipeline.

Topics to cover:
- [ ] OWASP Top 10 — what each vulnerability is and how your pipeline mitigates it
- [ ] Secret scanning deep dive — Gitleaks config, custom rules, pre-commit hooks
- [ ] Azure Key Vault integration — inject secrets into pods via CSI driver instead of K8s Secrets
- [ ] Container hardening checklist — distroless images, seccomp profiles, network policies
- [ ] Dependency scanning — `dotnet list package --vulnerable` in pipeline

How it connects to your repo:
- `security.yml` already has Gitleaks + SonarCloud — this module explains the "why" behind each
- `k8s/base/deployment.yaml` already has `readOnlyRootFilesystem`, `drop: ALL`, `runAsNonRoot` — this module explains what each prevents

---

## ⏳ 12. Observability
**What this adds:** Visibility into what your app is doing in AKS after deployment.

Topics to cover:
- [ ] Application Insights SDK in .NET 8 — add to `Program.cs`, instrument the health endpoint
- [ ] Azure Monitor Log Analytics — query pod logs with KQL
- [ ] Key KQL queries — error rate, response time, pod restarts
- [ ] Alert rules — notify when error rate exceeds threshold
- [ ] Durable Functions + App Insights — visual timeline of each orchestration step

How it connects to your repo:
- `src/DemoApi/Program.cs` — add `builder.Services.AddApplicationInsightsTelemetry()`
- `k8s/base/deployment.yaml` — add `APPLICATIONINSIGHTS_CONNECTION_STRING` env var from Key Vault

---

## 📋 13. Azure Governance Deep Dive
Topics to cover:
- [ ] Creating and assigning Azure Policies via CLI — enforce tags, deny public storage
- [ ] Management Group hierarchy — apply policies once, inherit everywhere
- [ ] Cost Management budgets — alert when spend exceeds threshold
- [ ] Compliance dashboard — view which resources violate policies

---

## 📋 14. GitOps with ArgoCD
Topics to cover:
- [ ] Install ArgoCD on AKS
- [ ] ArgoCD Application manifest — point at `k8s/overlays/` in your repo
- [ ] Drift detection — ArgoCD alerts when cluster state diverges from Git
- [ ] ArgoCD vs Flux — when to use each
- [ ] How this changes your `app.yml` — pipeline writes to Git, ArgoCD deploys

---

## 📋 15. PR Plan Comments
Topics to cover:
- [ ] Pass `terraform plan` output as artifact between jobs
- [ ] Post plan output as GitHub PR comment using `actions/github-script`
- [ ] Why this matters — infra changes reviewed like code, before they merge

---

## Concepts to Memorise — Skeletons Only

These are the minimum you should be able to write from memory in an interview.

**Terragrunt child file — 10 lines:**
```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../modules/aks-acr"
}

inputs = {
  environment = "dev"
  node_count  = 1
}
```

**Kustomize overlay — 10 lines:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

images:
  - name: demoapi
    newName: myacr.azurecr.io/demoapi
    newTag: latest
```

**Durable orchestrator skeleton — 10 lines:**
```csharp
[FunctionName("MyOrchestrator")]
public static async Task RunOrchestrator(
    [OrchestrationTrigger] IDurableOrchestrationContext context)
{
    var result = await context.CallActivityAsync<string>("ActivityOne", null);
    if (result == "retry")
        await context.CallActivityAsync("ActivityTwo", null);
}
```

---

## Real Errors You Have Debugged

| Error | Root Cause | Fix |
|-------|-----------|-----|
| State lock hang | Previous run cancelled before releasing blob lease | `az storage blob lease break` |
| `AuthorizationFailed` on role assignment | SP had Contributor but not UAA | Add User Access Administrator scoped to infra RG |
| `ARM Config error — CLI only supported as User` | `use_azuread_auth=true` + SP session incompatible | Remove `use_azuread_auth`, set `ARM_ACCESS_KEY` at job level |
| `Value for undeclared variable` | Typo in `variables.tf` (`resouce` vs `resource`) | All three must match: declaration, `var.name`, `TF_VAR_` |
| `OIDCIssuerFeatureCannotBeDisabled` | Imported existing AKS without capturing `oidc_issuer_enabled = true` | Add `oidc_issuer_enabled = true` to `main.tf` |
| `exec format error` | Image built on Apple Silicon without `--platform linux/amd64` | Add `--platform linux/amd64` to `docker buildx build` |
| Folder typo `enviroments` | Missing `n` in folder name, pipeline path used correct spelling | `Rename-Item`, clear `.terragrunt-cache` |
| `ImagePullBackOff` after ACR import | Deployed before `az acr import` fully propagated | `monitor-staging-acr` / `monitor-prod-acr` jobs poll until 200 |

---

*Last updated: April 2026 | Next session: Durable Functions — retry policies and sub-orchestrations*