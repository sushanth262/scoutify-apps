param(
    [string]$Namespace = "scoutify",
    [string]$KubeContext = "docker-desktop"
)

$ErrorActionPreference = "Stop"

Write-Host "== Scoutify Local Prerequisites ==" -ForegroundColor Cyan

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' is not installed or not in PATH."
    }
}

Require-Command "kubectl"
Require-Command "terraform"
Require-Command "docker"

Write-Host "Using Kubernetes context: $KubeContext"
kubectl config use-context $KubeContext | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to switch kubectl context to '$KubeContext'. Verify the context exists (`kubectl config get-contexts`)."
}

# Probe cluster connectivity without failing on native-command stderr.
& kubectl get nodes --request-timeout=10s *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Kubernetes context '$KubeContext' is set but not reachable. Start your local cluster (Docker Desktop Kubernetes or minikube) and retry."
}

$existingNamespace = & kubectl get namespace $Namespace -o name --ignore-not-found 2>$null
if ([string]::IsNullOrWhiteSpace($existingNamespace)) {
    kubectl create namespace $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create namespace '$Namespace'."
    }
}

Write-Host "Namespace '$Namespace' is ready."
Write-Host "Create tfvars files from examples before deploy:" -ForegroundColor Yellow
Write-Host "  deployment\infrastructure\terraform\environments\dev\terraform.tfvars.example"
Write-Host "  deployment\services\terraform\environments\dev\terraform.tfvars.example"
Write-Host ""
Write-Host "Recommended local defaults:" -ForegroundColor Yellow
Write-Host "  deployment_local = true"
Write-Host "  namespace = `"$Namespace`""
Write-Host "  kubeconfig_context = `"$KubeContext`""
Write-Host ""
Write-Host "After editing tfvars, run:" -ForegroundColor Green
Write-Host "  cd deployment\infrastructure\terraform"
Write-Host "  terraform init"
Write-Host "  terraform apply -var-file=environments/dev/terraform.tfvars"
Write-Host ""
Write-Host "  cd ..\..\services\terraform"
Write-Host "  terraform init"
Write-Host "  terraform apply -var-file=environments/dev/terraform.tfvars"
