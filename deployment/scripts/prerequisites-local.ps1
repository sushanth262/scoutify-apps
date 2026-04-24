param(
    [string]$Namespace = "scoutify",
    [string]$KubeContext = "minikube"
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

if (-not (kubectl get namespace $Namespace -o name 2>$null)) {
    kubectl create namespace $Namespace | Out-Null
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
