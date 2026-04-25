# Deployment Scripts

This folder contains PowerShell helpers for local Scoutify deployment workflows.

## `prerequisites-local.ps1`

Use this script as a pre-flight check before local deployment.

What it does:

- Verifies required tools are installed: `kubectl`, `terraform`, and `docker`
- Switches `kubectl` to the target context
- Ensures the target namespace exists (creates it if missing)
- Prints reminders for local `terraform.tfvars` setup
- Prints the Terraform commands to run next

It does **not** build images or deploy services by itself.

### Usage

Default usage (legacy minikube context):

```powershell
.\prerequisites-local.ps1
```

Docker Desktop Kubernetes usage:

```powershell
.\prerequisites-local.ps1 -Namespace scoutify -KubeContext docker-desktop
```

## `deploy-local-desktop.ps1`

Use this script for end-to-end local desktop deployment automation.

What it does:

- Reads deployment secrets/config from Windows environment variables
- Injects `VITE_GOOGLE_CLIENT_ID` into the UI image build (falls back to `GOOGLE_CLIENT_ID` if needed)
- Builds each service using the correct tool (`dotnet` or `npm`)
- Builds Docker images and saves image archives under `deployment/images`
- Writes Terraform var snapshots under `deployment/images/terraform-vars`
- Stores Terraform state files under `deployment/images/terraform-state`
- Applies services Terraform in local mode to your Kubernetes context
- Retries `terraform init` automatically (exponential backoff) for transient network/provider registry failures
- Uses Terraform provider cache and registry timeout/retry tuning to make repeated runs more reliable on unstable connections
- Seeds local Vault (`secret/openai-api-key`, `secret/alpha-vantage`, `secret/finnhub`) from your environment variables after deploy
- Restarts `ai-analysis-worker` after Vault seeding so it picks up fresh secrets

Note:

- In local mode, infrastructure Terraform is intentionally skipped to avoid Azure authentication requirements (`az login`) since Azure resources are not needed for Docker Desktop local deployment.

### Usage

```powershell
.\deploy-local-desktop.ps1 -EnvironmentName dev -Namespace scoutify -KubeContext docker-desktop
```
