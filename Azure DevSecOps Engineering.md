Azure DevSecOps Engineering
Complete Interview Preparation Guide with Q&A



Topics Covered

Docker  |  GitHub Actions CI/CD  |  Kubernetes (AKS)  |  Terraform  |  Terragrunt
Azure Governance  |  Image Promotion  |  Kustomize  |  Real Troubleshooting

Every interview question includes a detailed model answer

Target: Azure DevOps Engineer / Cyber Security DevOps
April 2026
 
1. Docker
What Is Docker and Why Use It?
Docker is a containerisation platform that packages an application with all its dependencies into a single portable unit called a container. The container runs identically on any machine with Docker installed — eliminating environment inconsistencies between development and production.

Before Docker, deploying a .NET API required the exact same .NET runtime version on every server. With Docker the runtime is bundled inside the image. You ship the image and it runs the same everywhere — developer laptop, CI pipeline runner, and AKS production nodes.

Image vs Container — The Core Distinction
Concept	Explanation
Image	Read-only blueprint — like a class in C#. Contains app, runtime, OS layers. Built once, reused many times. Immutable.
Container	Running instance of an image — like an object instantiated from a class. Has its own isolated filesystem and network.
Registry	Storage for images. Azure Container Registry (ACR) is Microsoft's managed registry. Like NuGet but for Docker images.
Dockerfile	Ordered instructions to build an image — FROM, COPY, RUN, ENTRYPOINT executed in sequence.

Multi-Stage Dockerfile
A multi-stage build uses two FROM statements in one Dockerfile. Stage one (build) uses the full SDK to compile the code. Stage two (runtime) uses only the slim aspnet image and copies the compiled output from stage one. The final image contains no SDK, no source code — only what is needed to run the app. This reduces image size from roughly 700MB to 200MB and eliminates development tools from the attack surface.

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /app
COPY src/DemoApi/DemoApi.csproj ./
RUN dotnet restore
COPY src/DemoApi/ ./
RUN dotnet publish -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app
COPY --from=build /out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "DemoApi.dll"]

Platform Targeting — linux/amd64
AKS nodes run on Linux with AMD64 CPUs. If you build on Apple Silicon (ARM64) without specifying the platform, the image will be ARM64 and fail on AKS with exec format error. The --platform linux/amd64 flag forces the correct architecture regardless of build machine.

docker buildx build --platform linux/amd64 -f docker/DemoApi.Dockerfile -t myacr.azurecr.io/demoapi:abc123 --push .

Common Errors and Fixes
Error	Cause and Fix
exec format error	Wrong CPU arch. Add --platform linux/amd64 to build command.
ImagePullBackOff	AKS cannot pull from ACR. Check ACR attachment via Terraform role assignment or az aks update --attach-acr.
Port not accessible	Port not mapped. Add EXPOSE in Dockerfile and -p 8080:8080 when running locally.
Image not found	Tag mismatch. Check full ACR login server URL matches image name exactly.

Interview Questions & Answers
Q1: What is the difference between a Docker image and a container?
An image is a read-only blueprint containing your application, runtime, and all dependencies. It is immutable — once built it never changes. A container is a running instance of that image. The relationship mirrors class and object in C#. The image is the class definition, the container is the instantiated object. You can run many containers from one image simultaneously, each with its own isolated filesystem and network namespace.
Q2: Why use multi-stage builds and what is the benefit?
Multi-stage builds keep build tools out of the production image. In a single-stage build you need the full .NET SDK to compile, so the final image contains the SDK — around 700MB of tools not needed at runtime that add unnecessary vulnerabilities. With a multi-stage build, stage one uses the SDK to compile and publish the app, stage two uses the slim aspnet runtime image and copies only the compiled output. The final image is around 200MB with no compiler, no source code, and no dev tools. Security and size both improve significantly.
Q3: How does AKS pull images from ACR without storing credentials?
AKS uses a Managed Identity — specifically the kubelet identity assigned to each node. The Terraform azurerm_role_assignment resource grants the kubelet managed identity the AcrPull role on the ACR. When a pod starts and needs to pull an image, the node authenticates using its managed identity token. Azure AD validates the token and exchanges it for an ACR access token. No credentials are stored anywhere — authentication is entirely token-based using Azure's identity platform. This is why admin_enabled = false is set on the ACR in Terraform.
Q4: What does --platform linux/amd64 do and when do you need it?
It forces Docker to build an image for the AMD64 (x86_64) CPU architecture regardless of the machine you are building on. AKS nodes run on Linux AMD64. If you build on Apple Silicon without this flag, Docker builds ARM64 by default. When AKS tries to run that container on an AMD64 node, the kernel cannot execute ARM64 binaries and throws exec format error. In GitHub Actions this flag is always good practice because it makes the build architecture explicit and prevents platform surprises if the runner type changes.
 
2. GitHub Actions CI/CD
Pipeline Structure
A GitHub Actions workflow is a YAML file in .github/workflows/. The on: block defines triggers. The jobs: block defines what runs. Each job runs on a fresh virtual machine called a runner. Steps within a job share the runner filesystem. Steps between different jobs do not — they run on separate machines and cannot share files without explicitly passing artifacts.

Concept	Explanation
on: push	Trigger when code is pushed to a branch. Use paths: to only trigger on relevant file changes.
on: workflow_dispatch	Manual trigger with optional typed input parameters shown as a form in the GitHub UI.
jobs:	Parallel or sequential groups of steps. All jobs start in parallel by default.
needs:	Makes job B wait for job A to complete successfully. Creates a dependency chain.
environment:	Links job to a GitHub Environment with its own secrets and optional approval gates.
secrets.*	Encrypted values stored in GitHub. Never visible in logs. Can be repository-level or environment-level.
concurrency:	Prevents two pipeline runs from competing simultaneously for the same resource.
if: condition	Conditionally skip a job. Used with always() to run even if previous jobs failed or were skipped.

AZURE_CREDENTIALS — Service Principal Authentication
The pipeline authenticates to Azure using a Service Principal stored as AZURE_CREDENTIALS. This JSON blob contains clientId, clientSecret, subscriptionId, and tenantId. The azure/login@v1 action reads this secret and authenticates the Azure CLI. All subsequent steps — Terraform, ACR login, AKS context — use this authenticated session.

az ad sp create-for-rbac \
  --name 'github-actions-sp' \
  --role contributor \
  --scopes /subscriptions/<ID>/resourceGroups/<RG> \
  --sdk-auth

Least Privilege Role Assignments
Role — Scope	Reason
Contributor on infra RG	Create and manage AKS, ACR, and other infrastructure resources
User Access Administrator on infra RG	Allow Terraform to create the AcrPull role assignment for AKS
Contributor on state RG	Fetch storage account access key for Terraform backend
Storage Blob Data Contributor on state RG	Alternative keyless backend auth using Azure AD directly

Split Pipelines — infra.yml and app.yml
Combining infrastructure and application deployment in one pipeline means Terraform runs on every code push — wasting 3-4 minutes and risking accidental infra changes on app deployments. Two separate pipelines trigger only on relevant file changes.

Pipeline	Trigger Paths
infra.yml — Terragrunt	infra/** — only when Terraform or Terragrunt files change
app.yml — Build and Deploy	src/**, docker/**, k8s/** — only when application files change

Concurrency — Preventing State Lock Conflicts
Two simultaneous pipeline runs both try to acquire the Terraform state blob lease. One succeeds, one waits. If the waiting run is cancelled, the lease may be left orphaned. The concurrency block queues runs so only one executes at a time.

concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false  # queue not cancel — never interrupt mid-apply

Interview Questions & Answers
Q1: What is the difference between repository-level and environment-level secrets?
Repository-level secrets are available to all workflows regardless of which environment the job references. Environment-level secrets are only available when a job explicitly references that environment using the environment: key. This allows the same secret name to have different values per environment — ACR_NAME can be acrdemosouravdev in the dev environment and acrdemosouravprod in the prod environment, each stored under their respective environment secrets. Repository secrets are used for values shared across all environments like AZURE_CREDENTIALS. Environment secrets hold environment-specific values like cluster names and resource groups.
Q2: How do you prevent two pipeline runs from corrupting Terraform state?
Two mechanisms work together. First, Terraform's built-in state locking acquires an exclusive blob lease before any operation and releases it afterward — if two runs start simultaneously only one acquires the lock and the other waits. Second, the GitHub Actions concurrency block with cancel-in-progress: false ensures only one run executes at a time by queuing subsequent runs rather than letting them race. The -lock-timeout=10m flag on plan and apply means a run waiting more than 10 minutes for a lock fails with a clear error including the Lock ID rather than hanging forever.
Q3: What does needs: do and why is cancel-in-progress: false important for infrastructure?
The needs: key creates a dependency between jobs making the current job wait for the specified job to complete successfully. Without needs: all jobs start in parallel. In a deployment pipeline needs: enforces ordering — deploy-dev waits for build, deploy-staging waits for deploy-dev. cancel-in-progress: false is critical for infrastructure pipelines because cancel-in-progress: true would cancel a running apply if a new run starts. If terraform apply is cancelled halfway through, some resources exist and others do not, leaving infrastructure in an inconsistent state that requires manual cleanup. Queuing is safe — the new run waits until the current apply completes cleanly.
Q4: How does the GitHub environment approval gate work for production?
When you configure required reviewers on a GitHub environment and a job references that environment, GitHub pauses the job before starting and sends notifications to reviewers. The job shows a waiting state in the Actions UI with an Approve button. The deployment only proceeds after an approved reviewer clicks Approve. This creates a mandatory human checkpoint before any prod deployment regardless of how the workflow was triggered. The gate cannot be bypassed by the pipeline code — it is enforced by GitHub's infrastructure.
 
3. Kubernetes on AKS
Core Components
Component	What It Does
Pod	Smallest deployable unit. One or more containers sharing a network namespace. Usually one container per pod.
Deployment	Manages desired pod state. Defines replica count and update strategy. Handles rolling updates and rollbacks.
ReplicaSet	Ensures exact number of running replicas. Created automatically by a Deployment.
Service	Stable network endpoint for pods. Provides consistent IP and DNS name since pod IPs change.
HPA	Horizontal Pod Autoscaler. Scales replicas based on CPU or memory metrics automatically.
ConfigMap	Non-sensitive config injected into pods as environment variables or mounted files.
Secret	Sensitive values (base64 encoded) mounted into pods. Use Key Vault CSI driver in production.
Ingress	HTTP routing rules. Routes external traffic to Services based on hostname and path.
Namespace	Logical isolation within a cluster. Separate dev, staging, prod or different teams.

Production Deployment Requirements
Every production Deployment must have resource requests and limits, liveness and readiness probes, and appropriate replica counts. Missing these is a red flag in interviews and causes real problems in production.

Resource requests — minimum guaranteed resources. Kubernetes uses these to decide which node to schedule the pod on.
Resource limits — maximum allowed. Exceed memory limit = OOMKilled. Exceed CPU limit = throttled but not killed.
Liveness probe — checks if the application is alive. Failure triggers container restart. Use for deadlocks and hangs.
Readiness probe — checks if the application is ready for traffic. Failure removes pod from load balancer without restarting.

resources:
  requests:
    cpu: '100m'      # 0.1 vCPU minimum guaranteed
    memory: '128Mi'
  limits:
    cpu: '500m'      # 0.5 vCPU hard maximum
    memory: '256Mi'  # exceed this = OOMKilled

livenessProbe:
  httpGet: { path: /health, port: 8080 }
  initialDelaySeconds: 10
  periodSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet: { path: /health, port: 8080 }
  initialDelaySeconds: 5
  periodSeconds: 10
  failureThreshold: 3

Common Pod Error States
Error	Cause and Fix
ImagePullBackOff	Cannot pull image. Check ACR attached to AKS and image name includes full registry URL.
CrashLoopBackOff	Container crashes immediately after starting. Check kubectl logs <pod> --previous for the exception.
OOMKilled	Exceeded memory limit. Increase limit or fix memory leak. Check kubectl describe pod for exit code 137.
Pending	Cannot be scheduled — no node has enough free resources. Check requests vs node capacity.
ProgressDeadlineExceeded	Deployment rollout timed out. New pods failing. Old pods still running. Investigate new pods with describe and logs.

Essential kubectl Commands
Command	What It Does
kubectl get pods	List pods and status in default namespace
kubectl describe pod <n>	Full details — image, events, probe results, error messages
kubectl logs <pod> --previous	Logs from the previous crashed container instance
kubectl apply -k k8s/overlays/dev	Apply using Kustomize overlay
kubectl rollout status deployment/<n>	Watch rollout progress — useful during deployments
kubectl rollout undo deployment/<n>	Roll back to previous ReplicaSet
kubectl get events --sort-by=.metadata.creationTimestamp	Recent cluster events for debugging

Interview Questions & Answers
Q1: What is the difference between liveness and readiness probes?
A liveness probe checks whether the application is still alive and functioning. Repeated failures cause Kubernetes to restart the container. Use this to recover from deadlocks or hangs where the process runs but cannot process requests. A readiness probe checks whether the application is ready to receive traffic. Failures remove the pod from the Service's load balancer endpoints but do not restart it. Use this during startup while the app initialises, or when a dependency becomes temporarily unavailable. A pod can be alive but not ready — it keeps running but receives no traffic until ready again.
Q2: What happens if you do not set resource limits on containers?
Without limits a container can consume as much CPU and memory as the node provides. If one container has a memory leak it can exhaust all node memory, causing the OS to kill other containers on the same node through OOM — affecting unrelated applications. Without CPU limits a busy container can starve other containers of CPU time. Without resource requests Kubernetes cannot make good scheduling decisions — it does not know how much space a pod needs on a node. In a cluster without limits set, one misbehaving application can cause cascading failures across services sharing the same node.
Q3: What does ProgressDeadlineExceeded mean and how do you fix it?
ProgressDeadlineExceeded means a Deployment's rolling update did not complete within the configured deadline (default 10 minutes). Kubernetes tried to replace old pods with new ones but the new pods never became ready. Old pods keep running to maintain availability. To diagnose: kubectl rollout status deployment/<name> to confirm the error, kubectl get pods to identify new failing pods, kubectl describe pod <new-pod> to see events and reasons, kubectl logs <new-pod> to see application errors. Common causes are the new image failing to pull, application crashing on startup, or readiness probes failing because the new version has a bug.
Q4: How does a Kubernetes rolling update achieve zero downtime?
With the default 25% maxUnavailable and 25% maxSurge on a 2-replica deployment: Kubernetes creates one new pod (the surge), waits for it to pass its readiness probe and be marked ready, then terminates one old pod. The new pod must pass readiness before any old pod is removed — at every point during rollout at least one pod serves traffic. Traffic only goes to pods that have passed readiness, so users are never sent to a pod still initialising. If new pods never become ready the rollout stalls — old pods keep running and the deployment shows ProgressDeadlineExceeded rather than silently breaking production.
Q5: Why do you need at least 2 nodes for true high availability with 2 replicas?
Two replicas on one node does not provide true high availability. If the node fails — hardware failure, OS crash, Azure VM maintenance — both replicas go down simultaneously and the application has zero availability. With two nodes, Kubernetes naturally places one replica on each node using default scheduling. If one node fails, the replica on the surviving node keeps the application running. The cluster detects the failed node and schedules a replacement pod on the surviving node within minutes. Without at least 2 nodes, the replica count is purely for load distribution, not availability.
 
4. Terraform
What Is Terraform and Why Not Use the Portal?
Terraform is an Infrastructure as Code tool. You write .tf files describing desired infrastructure state. Terraform compares desired state to what exists in Azure and makes only the necessary changes. It tracks everything it creates in a state file.

The portal cannot be reproduced exactly — recreating dev configuration in prod requires clicking through the same screens again and hoping nothing is missed. Portal changes leave no audit trail. They cannot be code-reviewed. Terraform solves all of these — .tf files are version-controlled, reviewed via pull requests, and reused across environments.

File Structure
File	Purpose
main.tf	All resource definitions — azurerm_resource_group, azurerm_kubernetes_cluster, azurerm_container_registry, azurerm_role_assignment
variables.tf	Variable declarations only — name, type, description, default. No actual values here.
outputs.tf	Values to export after apply — ACR login server URL, AKS cluster name, kubeconfig
backend.tf	Remote state configuration — leave empty, inject values via pipeline -backend-config flags
terraform.tfvars	Actual variable values for local development. Never commit to Git.

Core Commands
Command	When to Run and What It Does
terraform init	First command always. Downloads azurerm provider and connects to remote backend.
terraform validate	Checks syntax and variable references. Fast. Does not connect to Azure.
terraform plan	Connects to Azure. Shows exact diff — what will be created, modified, or destroyed.
terraform apply	Executes the changes shown in plan. Always review plan output first.
terraform destroy	Deletes all managed resources. Blocked by prevent_destroy lifecycle rule.
terraform state list	Shows all resources tracked in state file.
terraform import	Brings existing Azure resource under Terraform management without recreating it.
terraform force-unlock <id>	Manually releases stale state lock. Get lock ID from the error message.

Lifecycle Rules
Rule	What It Does and When to Use
prevent_destroy = true	Throws error instead of destroying. Use on production AKS, ACR, databases.
create_before_destroy = true	Creates replacement before deleting old resource. Prevents downtime during replacement.
ignore_changes = [field]	Ignores drift on specific fields. Use for node_count managed by AKS autoscaler.
replace_triggered_by = [resource]	Forces replacement when linked resource changes. Use for role assignments tied to AKS.

Remote State and State Lock
Terraform state maps .tf code to real Azure resources and stores sensitive outputs like kubeconfig. Remote state in Azure Blob Storage is shared across team members, keeps sensitive data out of Git, and provides automatic locking via blob leases. Only one Terraform operation can hold the lock at a time.

State Lock — Root Cause and Fix
When terraform apply runs it acquires a lease on the state blob.
If the pipeline is cancelled or crashes the lease is never released.
The next run hangs at 'Acquiring state lock' because the blob is still leased.
Fix: az storage blob lease break --account-name <sa> --container-name tfstate --blob-name <key> --auth-mode login
Prevention: concurrency block in pipeline (cancel-in-progress: false) ensures only one run at a time.
Detection: -lock-timeout=10m fails cleanly after 10 minutes instead of hanging forever.

Provider Aliases — Multi-Region
Provider aliases allow deploying to multiple Azure regions or subscriptions in one Terraform run. Each alias is a separate provider configuration. Resources explicitly reference which alias to use via the provider argument.

provider "azurerm" { features {} }  # default
provider "azurerm" { features {}; alias = "westeurope" }  # aliased
resource "azurerm_resource_group" "dr" {
  provider = azurerm.westeurope  # uses the aliased provider
  location = "westeurope"
}

Interview Questions & Answers
Q1: What is Terraform state and what problems does remote state solve?
Terraform state is a JSON file mapping .tf resources to real Azure infrastructure. It stores resource IDs, current attribute values, and dependencies. Terraform uses it to calculate changes needed on each plan run — comparing desired state in .tf files against current state in the file. Remote state in Azure Blob Storage solves three problems. First, it is shared — all team members and the CI pipeline read and write the same state. Second, it keeps sensitive data out of Git — the state file contains outputs like kubeconfig that must never be committed. Third, Azure Blob lease mechanism provides automatic locking so two simultaneous applies cannot corrupt the state.
Q2: What is the difference between terraform plan and terraform apply?
Terraform plan connects to Azure, reads the current state of all managed resources, compares them to the .tf configuration, and produces a human-readable diff showing what would be created, modified, or destroyed. It makes no changes — it is a preview. Terraform apply executes those changes. The recommended CI/CD pattern is: run plan on every pull request so reviewers see infrastructure changes before they are merged, then run apply only after the PR is approved and merged. This is the infrastructure equivalent of a code review — review what will change before it happens.
Q3: Why should terraform.tfvars not be committed to Git?
In production terraform.tfvars contains actual values for variables. Some are non-sensitive like resource group names and locations, but others are sensitive like database passwords, client secrets, API keys, and subscription IDs. Even non-sensitive values like resource group names and cluster names give an attacker a detailed map of your infrastructure. The correct pattern is to keep terraform.tfvars in .gitignore for local development only, and pass all values through the pipeline using TF_VAR_ environment variables sourced from GitHub Secrets. Sensitive values are encrypted in GitHub and never appear in version control history.
Q4: When would you use terraform import and what is the risk?
Terraform import brings an existing Azure resource — created outside Terraform via portal or CLI — under Terraform management without destroying and recreating it. You run terraform import <resource_address> <azure_resource_id> and Terraform adds it to state. The risk is that your .tf configuration may not capture all settings on the real resource. If the existing AKS cluster has OIDC issuer enabled but main.tf does not include oidc_issuer_enabled = true, the next apply tries to disable it — Azure rejects this because OIDC cannot be disabled once enabled. After importing always run terraform plan and carefully review every proposed change before applying.
Q5: What does prevent_destroy do and when is it used in production?
prevent_destroy = true in a resource's lifecycle block causes Terraform to throw an error and stop if any operation would destroy that resource — even terraform destroy. This is the last line of defense against accidental deletion of critical infrastructure. In production this goes on the AKS cluster, ACR, database servers, and storage accounts holding application data. It protects against mistakes like accidentally running terraform destroy in a prod context, a refactor that removes a resource block without realising it, or a plan that decides to replace a resource when you only wanted to update it. To intentionally destroy the resource you must first remove or comment out the prevent_destroy lifecycle block, then rerun apply.
 
5. Terragrunt
The Problem — Environment Duplication
With plain Terraform managing three environments means duplicating your entire folder for dev, staging, and prod. If you fix a bug in main.tf you fix it in three places. One environment inevitably drifts from the others. Terragrunt solves this by letting you write Terraform once in a module and reference it from lightweight per-environment files that only contain values.

Folder Structure
infra/
  terragrunt.hcl                    # root — remote state, provider, shared config
  modules/
    aks-acr/
      main.tf                        # written once — all environments use this
      variables.tf
      outputs.tf
  environments/
    dev/terragrunt.hcl               # dev values only — ~15 lines
    staging/terragrunt.hcl           # staging values only — ~15 lines
    prod/terragrunt.hcl              # prod values only — ~15 lines

Root terragrunt.hcl — Written Once
The root file defines remote state config using path_relative_to_include() to auto-generate unique state keys per environment. The generate blocks write backend.tf and provider.tf into each environment before Terraform runs — you never write these manually.

remote_state {
  backend = "azurerm"
  generate = { path = "backend.tf"; if_exists = "overwrite_terragrunt" }
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatedemo"
    container_name       = "tfstate"
    key = "${path_relative_to_include()}/terraform.tfstate"
    # dev  -> environments/dev/terraform.tfstate
    # prod -> environments/prod/terraform.tfstate
  }
}

Child terragrunt.hcl — Per Environment
include "root" { path = find_in_parent_folders() }

terraform { source = "../../modules/aks-acr" }

inputs = {
  resource_group_name = "rg-demoapi-dev"
  aks_cluster_name    = "aks-dotnet-demo-dev"
  aks_node_count      = 1
  aks_node_size       = "Standard_B2s"
  environment         = "dev"
}

How inputs Reaches Terraform
Terragrunt converts every key in the inputs block to a TF_VAR_ environment variable before calling Terraform. So aks_node_count = 1 becomes TF_VAR_aks_node_count=1. Terraform reads TF_VAR_ variables automatically, matching by name to declared variables. No -var flags needed in the pipeline when using Terragrunt.

Key Functions
Function	What It Does
find_in_parent_folders()	Walks up the directory tree to find root terragrunt.hcl automatically. No hardcoded paths.
path_relative_to_include()	Returns path from root to current environment. Used to generate unique state file keys automatically.

dependency Block — Cross-Module Output Sharing
Use the dependency block when one Terragrunt module needs outputs from another module. Example: AKS module needs Subnet ID from a networking module. For self-contained environments like DemoApi where each environment creates all its own resources, the dependency block is not needed.

dependency "networking" {
  config_path = "../networking"
  mock_outputs = { subnet_id = "/subscriptions/mock/subnet" }
}
inputs = { subnet_id = dependency.networking.outputs.subnet_id }

Interview Questions & Answers
Q1: What problem does Terragrunt solve that plain Terraform cannot?
Terragrunt eliminates the duplication of Terraform configuration across multiple environments. With plain Terraform, managing dev, staging, and prod requires either duplicating your entire .tf file set three times — leading to drift when you fix bugs in one but forget the others — or using Terraform workspaces which share a single state file providing poor isolation. Terragrunt lets you write your Terraform module once and reference it from lightweight per-environment files that only contain values specific to that environment. It auto-generates backend.tf and provider.tf per environment from a single root configuration, and uses path_relative_to_include() to generate unique state keys per environment without any repetition.
Q2: How does Terragrunt ensure each environment has its own isolated state file?
In the root terragrunt.hcl the remote state key is defined using path_relative_to_include(): key = "${path_relative_to_include()}/terraform.tfstate". When Terragrunt runs from environments/dev this function returns 'environments/dev', making the key 'environments/dev/terraform.tfstate'. From environments/prod the key becomes 'environments/prod/terraform.tfstate'. Each environment writes to a completely separate blob. A terraform apply in dev reads and writes only its own state — it is impossible for dev operations to affect prod state.
Q3: What does find_in_parent_folders() do and why is it better than hardcoding a path?
find_in_parent_folders() is a built-in Terragrunt function that walks up the directory tree until it finds a terragrunt.hcl file. Called from infra/environments/dev/terragrunt.hcl it finds infra/terragrunt.hcl automatically. This is better than hardcoding because if you reorganise your folder structure all child files still find the root without manual path updates. Hardcoded relative paths like ../../terragrunt.hcl would all break and require manual updates. It also communicates intent clearly: find the root configuration wherever it is.
Q4: What replaces -var flags when using Terragrunt and how does it work?
The inputs block in the child terragrunt.hcl replaces -var flags. When Terragrunt calls Terraform it converts each key-value pair in inputs to a TF_VAR_ environment variable. So inputs = { environment = 'dev', aks_node_count = 1 } becomes TF_VAR_environment=dev and TF_VAR_aks_node_count=1 in the Terraform process environment. Terraform reads TF_VAR_ variables automatically matching by name. This is cleaner than -var flags because the values are version-controlled files rather than long pipeline commands, and Terragrunt handles the translation with no extra configuration.
Q5: When would you use the dependency block?
Use the dependency block when one module needs output values from another to function. Classic example: a networking module creates VNets and Subnets, and an AKS module needs the Subnet ID to place nodes in the correct network. Without dependency you would hardcode the subnet ID or use terraform_remote_state with verbose backend config. Do not use the dependency block when environments are self-contained — when each creates all its own resources without needing IDs from other modules. In the DemoApi project each environment creates its own resource group, ACR, and AKS independently so no outputs are shared and no dependency blocks are needed.
 
6. Image Promotion — Build Once, Deploy Everywhere
Why Build Once?
Rebuilding the Docker image for each environment means the image deployed to staging may not be identical to the one tested in dev — even with the same source code. Different base image layers may be pulled, different package versions may resolve. The correct enterprise approach is to build once, tag with the git commit SHA, and promote the same immutable image through environments.

ACR Import — How Promotion Works
The az acr import command copies an image between registries entirely within the Azure network. No download, no upload, no bandwidth consumed. The image content digest (SHA256) is preserved — the prod image is cryptographically identical to the dev image, not just built from the same source.

az acr import \
  --name <target-acr>
  --source <source-acr>.azurecr.io/demoapi:<sha>
  --image demoapi:<sha>
  --force

Full Promotion Flow
Stage	What Happens
Build	Image built once, pushed to dev ACR with git SHA as tag. SHA is immutable.
Deploy Dev	Deploy from dev ACR to dev AKS. First validation.
Promote to Staging	az acr import copies from dev ACR to staging ACR. Same SHA, same content digest.
Deploy Staging	Deploy from staging ACR to staging AKS. Integration testing and QA.
Promote to Prod	az acr import from dev ACR (source of truth) to prod ACR. Never from staging.
Approve and Deploy Prod	Manual approval gate then deploy from prod ACR to prod AKS.

Rollback Workflow
A separate rollback.yml workflow handles emergency rollbacks. The engineer selects the target environment and the git SHA of the last known good build. The workflow imports that SHA from dev ACR directly to the target environment and deploys it — bypassing the normal promotion chain. Prod approval still applies.

Interview Questions & Answers
Q1: Why build once and promote rather than rebuilding per environment?
Rebuilding introduces risk — even with identical source code two builds may produce different images if base layers have been updated between builds or if package resolution pulls different minor versions. By building once and promoting, you guarantee what you tested in dev is exactly what runs in staging and exactly what runs in prod. The SHA tag makes this traceable — every running container maps to the exact source code commit it contains. In regulated industries like banking this traceability is a compliance requirement — you may need to audit precisely what code ran in production at any given time.
Q2: What is az acr import and why is it better than docker pull and push?
az acr import is an Azure CLI command that copies an image between container registries using server-side copy within the Azure network. It is better than docker pull plus docker push for several reasons. Speed — no image data leaves Azure so there is no download to the pipeline runner and no re-upload, saving minutes for large images. Content integrity — the SHA256 digest is preserved in the destination so the image is cryptographically identical. No Docker daemon required — the copy is performed by Azure infrastructure. No docker login required — just the Azure CLI authenticated session.
Q3: How do you handle emergency rollbacks without going through all environments?
We have a separate rollback.yml workflow with workflow_dispatch inputs for image_tag and environment. The engineer selects the target environment and the git SHA of the last known good build. The workflow imports that specific image from dev ACR directly to the target environment's ACR using az acr import, then deploys it. The normal dev and staging stages are bypassed entirely. For prod the GitHub environment approval gate still applies — a second person must approve even emergency rollbacks, ensuring two-person integrity.
Q4: Why is dev ACR used as the import source for prod rather than staging ACR?
Dev ACR is the universal source for all promotions and rollbacks because every image ever built exists there. Staging ACR only contains images promoted to staging, which may be a subset. If you need to deploy a build to prod that was never through staging — for example an emergency fix — dev ACR is the only reliable source. If staging ACR had an issue and prod imported from staging, prod deployments would be blocked. Using dev ACR as the universal source means staging ACR problems never affect prod.
 
7. Kustomize
Why Kustomize — Replacing the sed Hack
Using sed to replace placeholders in deployment.yaml modifies the actual file on the runner, is fragile if sed fails silently, and cannot handle per-environment differences beyond simple text replacement. Kustomize is built into kubectl — it renders a final manifest in memory from a base and overlay, never modifying source files.

Approach	Issues
sed -i 's|PLACEHOLDER|value|g' deployment.yaml	Modifies files. Single environment only. No validation. Fragile if pattern does not match.
kubectl apply -k k8s/overlays/dev	Never modifies source files. Per-environment overlays. Kubernetes-native. Validated.

Structure — Base and Overlays
k8s/
  base/
    deployment.yaml         # common config — image, probes, resources
    service.yaml
    hpa.yaml
    kustomization.yaml      # lists base resources
  overlays/
    dev/kustomization.yaml  # 1 replica, Development env, dev ACR
    staging/kustomization.yaml
    prod/kustomization.yaml # 2 replicas, Production env, prod ACR

Per-Environment Differences
Setting	Dev	Prod
ASPNETCORE_ENVIRONMENT	Development	Production
replicas	1	2
Image registry	dev ACR URL	prod ACR URL

Image Tag Substitution in Pipeline
cd k8s/overlays/dev
kubectl kustomize . | \
  sed 's|demoapi:latest|myacr.azurecr.io/demoapi:$SHA|g' | \
  kubectl apply -f -

Kustomize vs Helm
Kustomize	Helm
Built into kubectl — no extra installation	Requires separate helm CLI installation
Patch-based — modify existing YAML	Template-based — Go template syntax throughout
No templating language to learn	Requires learning Go template syntax and chart structure
Good for simple per-environment differences	Better for complex parameterised reusable deployments

Interview Questions & Answers
Q1: What is Kustomize and how does it differ from Helm?
Kustomize is a Kubernetes-native configuration management tool built into kubectl. It works by patching existing YAML files — you write your base manifests normally and write overlay files specifying what to change per environment. No templating language involved. Helm is a package manager for Kubernetes that uses Go templates to generate manifests from parameterised chart files. Kustomize is better for teams already comfortable with Kubernetes YAML who need simple per-environment differences without learning a new templating syntax. Helm is better when you need to package, version, and distribute applications as reusable charts or when parameterisation requirements are complex enough to benefit from a full templating engine.
Q2: What is the difference between base and overlays in Kustomize?
The base folder contains common Kubernetes manifests that apply to all environments — Deployment, Service, HPA, and a kustomization.yaml listing them. The base represents the default desired state. Overlays are per-environment directories each with their own kustomization.yaml referencing the base and specifying changes. An overlay might change replica count, set a different environment variable, reference a different container image registry, or add extra labels. Kustomize merges base with overlay using strategic merge patches, producing a complete manifest without modifying source files. The base is committed once and shared. Overlays are small files containing only the differences.
Q3: Why is kubectl apply -k better than sed for manifest substitution?
The sed approach modifies the actual file on the pipeline runner. If sed fails silently the placeholder is deployed and pods fail. More importantly, sed can only do text replacement — it cannot understand Kubernetes resource structure, cannot validate the result is valid YAML, and cannot handle complex configuration differences between environments. kubectl apply -k renders the final manifest in memory by merging base with overlay, validates the result, and applies it atomically. Source files are never modified. Each environment has an explicit overlay defining exactly what it needs, version-controlled and reviewed as code rather than a sed command in a pipeline script.
 
8. Azure Governance
Azure Resource Hierarchy
Azure organises resources in a four-level hierarchy. Policies and RBAC applied at any level inherit downward. This allows organisation-wide security policies to be applied once at the Management Group level rather than repeated on every subscription.

Azure AD Tenant
  Tenant Root Group
    Management Group: Production
      Subscription: prod-workloads
        Resource Group: rg-demoapi-prod
          AKS, ACR, Storage...
    Management Group: Non-Production
      Subscription: dev-workloads

RBAC — Role-Based Access Control
RBAC controls who can perform what actions on which resources. Every assignment has three components: principal (who — user, group, or SP), role definition (what — set of allowed actions), and scope (where — subscription, resource group, or specific resource).

Built-in Role	What It Allows
Owner	Full control including managing role assignments. Never assign to automated Service Principals.
Contributor	Create, update, delete resources. Cannot manage role assignments. Standard for automation.
Reader	View all resources but cannot change them. Good for monitoring tools.
User Access Administrator	Manage role assignments. Needed for Terraform to assign AcrPull to AKS.
AcrPull	Pull images from a specific ACR. Assigned to AKS kubelet managed identity.
Storage Blob Data Contributor	Read, write, delete blobs. Used for Terraform remote state keyless auth.

Azure Policy
Effect	What Happens on Policy Violation
Audit	Resource created but flagged non-compliant in compliance dashboard.
Deny	Resource creation blocked. Operation fails with policy violation error.
DeployIfNotExists	Azure automatically deploys a required companion resource if missing.
Modify	Azure automatically adds or corrects resource properties for compliance.

Tagging Strategy
Tags are key-value metadata enabling cost attribution, automation targeting, and governance reporting. Every resource in this project includes standard tags enforced by the Terraform module.

tags = {
  environment = var.environment   # dev | staging | prod
  managed_by  = "terraform"       # do not edit manually
  project     = "demoapi"         # for cost attribution
}

Why UAA Is Needed Separately from Contributor
Contributor allows creating resources but explicitly CANNOT create role assignments.
When Terraform creates the AcrPull role assignment granting AKS permission to pull from ACR,
it needs Microsoft.Authorization/roleAssignments/write — blocked by Contributor alone.
User Access Administrator adds this specific permission.
Scoping UAA to the resource group rather than the subscription limits blast radius:
a compromised SP can only create role assignments within that RG, not across the whole subscription.

Interview Questions & Answers
Q1: What is the difference between RBAC and Azure Policy?
RBAC controls what actions an identity can perform — who can do what. A Contributor can create resources, a Reader cannot. RBAC operates at the identity level, granting or restricting permissions per principal. Azure Policy controls how resources must be configured — what can be created and how. A Deny policy prevents anyone from creating a storage account without encryption enabled, regardless of their RBAC role. A Contributor with a Deny policy on their resource group cannot create a non-compliant resource even though their RBAC role would normally allow it. RBAC and Policy complement each other: RBAC prevents unauthorized users from making changes, Policy ensures authorized users make compliant changes.
Q2: Why do you scope role assignments to resource groups rather than subscriptions?
Scoping to the smallest necessary scope follows the principle of least privilege. A Contributor scoped to a subscription can create, modify, and delete resources anywhere in that subscription — any resource group, any service. A Contributor scoped to rg-demoapi-dev can only affect resources within that resource group. If the pipeline Service Principal is compromised — credentials leaked — the attacker has access only to that resource group, not the entire subscription. The pipeline SP has Contributor on the infra resource group and Contributor on the state resource group. It cannot touch other resource groups, other subscriptions, or billing settings.
Q3: What is the principle of least privilege and how does it apply to your pipeline SP?
Least privilege means every identity has the minimum permissions needed to perform its function and nothing more. For the pipeline SP this means: Contributor on the infra resource group rather than the subscription, because the SP only manages resources in that specific group. User Access Administrator scoped to the infra resource group rather than the subscription, because the SP only creates the AcrPull role assignment within that group. Contributor on the state resource group for Terraform backend access. The SP cannot access other resource groups, manage billing, create subscriptions, or assign itself Owner. If credentials are leaked, the attacker is limited to those two resource groups.
Q4: How does tagging support governance and cost management?
Tags are key-value metadata on resources enabling several governance capabilities. For cost management, finance teams filter Azure cost reports by environment=prod to see production costs separately from dev, or by project=demoapi for project-specific spending. For automation, Azure Policy can require certain tags and deny creation of resources without them. For operations, managed_by=terraform tags tell teams not to modify the resource manually — it will be overwritten on the next apply. For security, compliance scripts find all resources without a data_classification tag identifying ungoverned resources. In regulated industries tagging is often a compliance requirement for data residency and audit purposes.
 
9. Real Troubleshooting — What Went Wrong and Why
Every error below was encountered while building this project. Understanding the root cause — not just the fix — is what separates junior from senior engineers in interviews.

Error 1: Pipeline hung at Acquiring state lock
Symptom: Shows 'Acquiring state lock. This may take a few moments...' and never proceeds.
Root cause: Previous pipeline run was cancelled or crashed after acquiring the state blob lease but before releasing it. Azure blob leases do not auto-expire.
Fix: az storage blob lease break --account-name <sa> --container-name tfstate --blob-name <key> --auth-mode login
Prevention: Concurrency block (cancel-in-progress: false) ensures only one run at a time. -lock-timeout=10m fails cleanly after 10 minutes.

Error 2: AuthorizationFailed creating role assignment
Symptom: Terraform apply fails with 403: does not have authorization to perform Microsoft.Authorization/roleAssignments/write
Root cause: Pipeline SP had Contributor but not User Access Administrator. Contributor explicitly excludes role assignment creation.
Fix: Add User Access Administrator role scoped to the infra resource group for the pipeline SP.

Error 3: ARM Config error — CLI only supported as User
Symptom: terraform init fails: Authenticating using the Azure CLI is only supported as a User (not a Service Principal).
Root cause: use_azuread_auth=true in backend config told Terraform to use Azure AD for storage auth. The runner's CLI session is a Service Principal. Azure AD storage auth needs Storage Blob Data Contributor separately.
Fix: Remove use_azuread_auth from backend config. Set ARM_ACCESS_KEY env var at job level so Terragrunt forwards it to the Terraform subprocess.

Error 4: Value for undeclared variable on plan
Symptom: terraform plan fails: A variable named 'resource_group_name' was assigned but the root module does not declare it.
Root cause: variables.tf had a typo: resouce_group_name (missing 'r'). Pipeline passed resource_group_name correctly. Two errors: pipeline var had no declaration, declaration had no value.
Fix: Correct the typo. All three must match: variables.tf declaration, var.name in main.tf, and TF_VAR_ or -var in pipeline.

Error 5: OIDCIssuerFeatureCannotBeDisabled
Symptom: terraform apply fails with 400 Bad Request: OIDC issuer feature cannot be disabled.
Root cause: Existing AKS cluster had OIDC issuer enabled. main.tf did not include oidc_issuer_enabled = true. Terraform tried to set it to false. Azure rejects this.
Fix: Add oidc_issuer_enabled = true to azurerm_kubernetes_cluster. When importing existing resources always capture all non-default settings.

Error 6: exec format error on pod start
Symptom: Pod enters CrashLoopBackOff. kubectl logs shows: exec /usr/bin/dotnet: exec format error.
Root cause: Image built on Apple Silicon (ARM64) without --platform linux/amd64. AKS nodes are AMD64. AMD64 kernel cannot execute ARM64 binaries.
Fix: Add --platform linux/amd64 to docker buildx build command in pipeline and locally.

Error 7: Folder name typo — enviroments vs environments
Symptom: Terragrunt cannot find environments folder. Path error in pipeline logs.
Root cause: Folder was named 'enviroments' (missing 'n'). Pipeline working-directory and source paths used correct spelling.
Fix: Rename-Item infra\enviroments infra\environments in PowerShell. Clear .terragrunt-cache before rerunning.

Key Lessons
•	Always run terraform validate and terraform plan locally before pushing. These catch 90% of errors in seconds.
•	Variable names must match exactly across variables.tf, var.name in main.tf, and TF_VAR_ env vars or -var flags in the pipeline.
•	State lock hangs are almost never permissions issues. Permissions failures show 403 immediately. Indefinite hang at lock = stale lease.
•	When importing existing resources, check all non-default settings in the portal and capture them in .tf files before applying.
•	Concurrency blocks are not optional for infrastructure pipelines. Set cancel-in-progress: false to queue, never cancel mid-apply.
•	Clear .terragrunt-cache when changing working directories or module sources. Old resolved paths are cached.
 
10. Interview Preparation Summary
What You Have Built
•	Containerised a .NET 8 Web API using Docker multi-stage builds targeting linux/amd64
•	Pushed images to Azure Container Registry and deployed to AKS with probes and resource limits
•	Infrastructure provisioned using Terraform with remote state in Azure Blob Storage
•	Terragrunt manages three isolated environments (dev, staging, prod) without duplicating Terraform code
•	Split CI/CD pipelines — infra.yml for infrastructure, app.yml for application deployment
•	Image promotion using ACR import — same immutable SHA-tagged image promoted through environments
•	Least privilege RBAC — pipeline SP scoped to specific resource groups with minimum required roles
•	State lock management with concurrency blocks and lock timeout flags
•	Kustomize overlays for per-environment Kubernetes manifest customisation
•	Production approval gates and a separate rollback workflow for emergency rollbacks

Answer Format — Problem, Solution, Enterprise Consideration
Template for Architecture Questions
Start with the problem: 'The challenge was...'
Describe your solution: 'We solved this using...'
Add enterprise consideration: 'In a larger team this would also need...'

Example: 'The challenge was managing three separate environments without duplicating
Terraform code. We solved this using Terragrunt which lets us write the module once
and reference it from lightweight per-environment files containing only values.
In a larger team this would extend to using the dependency block for cross-module
output sharing and separate approval requirements per environment.'

HSBC Cyber Security DevOps — Key Topics
Topic	Key Points to Mention
Security in CI/CD	Least privilege SP, secrets never in code, approval gates, image scanning, secret scanning
Infrastructure as Code	Terraform remote state, Terragrunt environments, prevent_destroy, state locking
Container security	Multi-stage builds, non-root users, resource limits, read-only filesystems, ACR scanning
Access control	RBAC minimum required roles scoped to resource group, SP per environment not subscription
Audit trail	Git history of all infra changes, tagged resources, deployment approvals, SHA-tagged images
Disaster recovery	Rollback workflow, dev ACR as image archive, prevent_destroy on critical resources
Shift left security	Scanning in pipeline before deployment — Trivy, SonarCloud, secret scanning

Topics Still to Cover
1.	DevSecOps — Trivy image scanning, SonarCloud code quality, secret scanning, OWASP Top 10
2.	Observability — Application Insights in .NET 8, Azure Monitor Log Analytics, KQL queries, alerting
3.	Azure Governance deep dive — creating Azure Policies, Management Groups, Cost Management budgets
4.	GitOps — ArgoCD on AKS, declarative cluster state, drift detection, ArgoCD vs Flux
5.	PR Plan Comments — Terraform plan output posted as GitHub PR comment for infra review

End of Document — Azure DevSecOps Engineering Interview Preparation Guide
Built through hands-on practice — April 2026
