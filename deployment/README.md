# 🚀 Deployment Configuration

This folder contains all deployment-related configurations for the Scoutify AI Stock Insights system.

## 📦 Git Repository Setup

To push this deployment configuration to GitHub:

1. **Quick Setup**: Run the setup script
   ```powershell
   .\setup-git.ps1
   ```

2. **Manual Setup**: Follow the [Git Setup Guide](./SETUP_GIT.md)

3. **Important**: Never commit `.tfvars` files with secrets! Use `.tfvars.example` files as templates.

## 📁 Folder Structure

```
deployment/
├── infrastructure/     # Infrastructure as Code (IaC)
│   ├── azure/         # Azure Bicep templates
│   └── terraform/     # Terraform configurations
│       ├── main.tf
│       ├── variables.tf
│       ├── local.tf          # Minikube resources
│       ├── azure.tf          # Azure resources
│       └── environments/     # Environment configs
│           ├── dev/
│           └── prod/
│
├── services/          # Service deployment configurations
│   ├── docker-compose/ # Docker Compose files
│   ├── kubernetes/    # Kubernetes manifests
│   └── terraform/     # Terraform service deployments
│       ├── main.tf
│       ├── kubernetes.tf
│       └── environments/
│           ├── dev/
│           └── prod/
│
├── terraform/         # Terraform deployment scripts
│   └── scripts/       # Helper scripts
│
└── environments/      # Environment-specific configs
    └── dev/          # Development environment
```

## 🎯 Deployment Mode Flag

All deployment flows now use one Terraform flag:

- `deployment_local = true` → Local desktop Kubernetes deployment
  - Uses local cluster context from kubeconfig
  - Deploys local RabbitMQ/Redis/Vault services in-cluster
  - Worker uses local vault mode (`KEYVAULT_VAULT_URL=local://`)

- `deployment_local = false` → Cloud deployment (Azure)
  - Infrastructure Terraform creates AKS + Service Bus + Key Vault
  - Services Terraform deploys Scoutify workloads to AKS namespace `scoutify`
  - Secrets are set as placeholders or CI-injected values pointing to Key Vault flow

## 📌 Namespace and Services

- Namespace is managed from TF vars: `namespace = "scoutify"` (default)
- All services are deployed via Terraform Kubernetes resources:
  - `scoutify-ui-host`
  - `scoutify-edge-gateway`
  - `scoutify-auth-api`
  - `scoutify-features-api`
  - `scoutify-stocks-api`
  - `ai-analysis-worker`
  - local-only infra services (`rabbitmq`, `redis`, `vault`) when `deployment_local = true`

## 🔐 Secrets and Environment Configuration

Terraform creates:
- `ConfigMap`: non-sensitive configuration/env values
- `Secret`: sensitive values and placeholders

Examples:
- `JWT__SIGNINGKEY`
- `GOOGLE_CLIENT_ID`
- `SERVICE_BUS_CONNECTION_STRING`
- `OPENAI_API_KEY`
- `ALPHA_VANTAGE_API_KEY`
- `FINNHUB_API_KEY`
- `LOCAL_VAULT__VAULT_ROOT_TOKEN`

> Use placeholders in `*.tfvars.example` and inject real values from local secure stores or GitHub Actions secrets.

## 🛠 Prerequisites

### Local desktop prerequisites (PowerShell)

Run:

```powershell
.\scripts\prerequisites-local.ps1 -Namespace scoutify -KubeContext minikube
```

This validates required tools (`kubectl`, `terraform`, `docker`), sets context, ensures namespace exists, and prints the exact apply commands.

### Cloud prerequisites (GitHub Actions)

Workflow:

- `.github/workflows/deploy-cloud.yml`

Required GitHub Secrets:
- `AZURE_CREDENTIALS`
- `JWT_SIGNING_KEY`
- `GOOGLE_CLIENT_ID`
- `OPENAI_API_KEY`
- `ALPHAVANTAGE_API_KEY`
- `FINNHUB_API_KEY`

## 🔧 Configuration

### Environment Variables

See [ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md) for all environment variables.

### Cost Optimization

See [infrastructure/azure/COST_OPTIMIZATION.md](./infrastructure/azure/COST_OPTIMIZATION.md) for cost optimization strategies.

## 📊 Deployment Comparison

| Method | Local | Azure | Cost | Best For |
|--------|-------|-------|------|----------|
| **Terraform** | ✅ Minikube | ✅ Azure | Free / ~$5-10 | Full automation |
| **Docker Compose** | ✅ Local | ❌ | Free | Local development |
| **Kubernetes** | ✅ Minikube | ✅ AKS | Free / ~$50+ | Production K8s |
| **Azure Bicep** | ❌ | ✅ Azure | ~$5-10 | Azure-only |

## 🚀 Quick Start

### Local Deployment (Kubernetes on Desktop)

```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars -var="deployment_local=true"

cd ../../services/terraform
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars -var="deployment_local=true"
```

### Cloud Deployment (AKS + Azure Services)

Either run the GitHub workflow (`Deploy Scoutify Cloud`) or apply manually:

```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars -var="deployment_local=false"

cd ../../services/terraform
terraform init
terraform apply -var-file=environments/dev/terraform.tfvars -var="deployment_local=false"
```

## 📝 Notes

- **Terraform** is the recommended approach for full automation
- **Local deployment** uses Kubernetes + local RabbitMQ/Redis/Vault services
- **Azure deployment** uses AKS + Azure Service Bus + Azure Key Vault
- **Infrastructure** must be deployed before **services**
- See individual README files in each folder for detailed instructions

## 🔗 Related Documentation

- [Terraform Deployment](./terraform/README.md)
- [Infrastructure Terraform](./infrastructure/terraform/README.md)
- [Services Terraform](./services/terraform/README.md)
- [Cost Optimization](./infrastructure/azure/COST_OPTIMIZATION.md)
- [Environment Variables](./ENVIRONMENT_VARIABLES.md)
