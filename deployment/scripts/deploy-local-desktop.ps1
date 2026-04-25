param(
    [string]$EnvironmentName = "dev",
    [string]$KubeContext = "docker-desktop",
    [string]$Namespace = "scoutify",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' is not installed or not in PATH."
    }
}

function Get-EnvValue {
    param(
        [string[]]$Names,
        [string]$DefaultValue = "",
        [switch]$Required
    )

    foreach ($name in $Names) {
        $value = [Environment]::GetEnvironmentVariable($name, "Process")
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($name, "User")
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($name, "Machine")
        }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }

    if ($Required) {
        throw "Missing required environment variable. Expected one of: $($Names -join ', ')"
    }

    return $DefaultValue
}

function Escape-TfvarsValue {
    param([string]$Value)
    $escaped = $Value.Replace("\", "\\").Replace('"', '\"')
    return """$escaped"""
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed: $FilePath $($ArgumentList -join ' ')"
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-WithRetry {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory,
        [int]$MaxAttempts = 4,
        [int]$InitialDelaySeconds = 3
    )

    $attempt = 1
    $delay = $InitialDelaySeconds

    while ($true) {
        try {
            Invoke-Checked -FilePath $FilePath -ArgumentList $ArgumentList -WorkingDirectory $WorkingDirectory
            return
        }
        catch {
            if ($attempt -ge $MaxAttempts) {
                throw
            }

            Write-Host "Attempt $attempt failed for: $FilePath $($ArgumentList -join ' ')" -ForegroundColor Yellow
            Write-Host "Retrying in $delay second(s)..." -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
            $attempt += 1
            $delay = [Math]::Min($delay * 2, 30)
        }
    }
}

function Wait-ForDeploymentReady {
    param(
        [string]$Namespace,
        [string]$DeploymentName,
        [string]$Timeout = "180s"
    )

    Invoke-Checked -FilePath "kubectl" -ArgumentList @(
        "rollout",
        "status",
        "deployment/$DeploymentName",
        "-n", $Namespace,
        "--timeout=$Timeout"
    ) -WorkingDirectory $repoRoot
}

function Seed-LocalVaultSecrets {
    param(
        [string]$Namespace,
        [string]$VaultToken,
        [hashtable]$SecretMap
    )

    Write-Host ""
    Write-Host "== Seeding local Vault secrets ==" -ForegroundColor Cyan

    Wait-ForDeploymentReady -Namespace $Namespace -DeploymentName "vault"

    $vaultPodName = (& kubectl get pods -n $Namespace -l app=vault -o jsonpath="{.items[0].metadata.name}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($vaultPodName)) {
        throw "Unable to locate Vault pod in namespace '$Namespace'."
    }

    foreach ($secretName in $SecretMap.Keys) {
        $secretValue = [string]$SecretMap[$secretName]
        if ([string]::IsNullOrWhiteSpace($secretValue)) {
            Write-Host "Skipping empty Vault secret '$secretName'." -ForegroundColor Yellow
            continue
        }

        Invoke-Checked -FilePath "kubectl" -ArgumentList @(
            "exec",
            "-n", $Namespace,
            $vaultPodName,
            "--",
            "env",
            "VAULT_ADDR=http://127.0.0.1:8200",
            "VAULT_TOKEN=$VaultToken",
            "vault",
            "kv",
            "put",
            "secret/$secretName",
            "value=$secretValue"
        ) -WorkingDirectory $repoRoot

        Write-Host "Seeded Vault secret: secret/$secretName"
    }
}

function Initialize-TerraformEnvironment {
    param([string]$RepoRootPath)

    # Keep provider binaries cached between runs to reduce registry fetches.
    $pluginCacheDir = Join-Path $RepoRootPath ".terraform.d\plugin-cache"
    New-Item -ItemType Directory -Path $pluginCacheDir -Force | Out-Null
    if ([string]::IsNullOrWhiteSpace($env:TF_PLUGIN_CACHE_DIR)) {
        $env:TF_PLUGIN_CACHE_DIR = $pluginCacheDir
    }

    # Increase registry tolerance for unstable networks.
    if ([string]::IsNullOrWhiteSpace($env:TF_REGISTRY_CLIENT_TIMEOUT)) {
        $env:TF_REGISTRY_CLIENT_TIMEOUT = "90s"
    }
    if ([string]::IsNullOrWhiteSpace($env:TF_REGISTRY_DISCOVERY_RETRY)) {
        $env:TF_REGISTRY_DISCOVERY_RETRY = "6"
    }

    # Prefer Go DNS resolver to avoid some Windows resolver edge-cases.
    if ([string]::IsNullOrWhiteSpace($env:GODEBUG)) {
        $env:GODEBUG = "netdns=go"
    }

    Write-Host "Terraform registry tuning enabled:"
    Write-Host "  TF_PLUGIN_CACHE_DIR=$env:TF_PLUGIN_CACHE_DIR"
    Write-Host "  TF_REGISTRY_CLIENT_TIMEOUT=$env:TF_REGISTRY_CLIENT_TIMEOUT"
    Write-Host "  TF_REGISTRY_DISCOVERY_RETRY=$env:TF_REGISTRY_DISCOVERY_RETRY"
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deploymentDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $deploymentDir
$imagesRoot = Join-Path $deploymentDir "images"
$terraformStateDir = Join-Path $imagesRoot "terraform-state"
$terraformVarsDir = Join-Path $imagesRoot "terraform-vars"

New-Item -ItemType Directory -Path $imagesRoot -Force | Out-Null
New-Item -ItemType Directory -Path $terraformStateDir -Force | Out-Null
New-Item -ItemType Directory -Path $terraformVarsDir -Force | Out-Null

Write-Host "== Scoutify Local Desktop Deploy ==" -ForegroundColor Cyan
Write-Host "Repo root: $repoRoot"
Write-Host "Deployment folder: $deploymentDir"
Write-Host "Images folder: $imagesRoot"
Write-Host "Kubernetes context: $KubeContext"
Write-Host ""

Require-Command "docker"
Require-Command "kubectl"
Require-Command "terraform"
Require-Command "dotnet"

Initialize-TerraformEnvironment -RepoRootPath $repoRoot

$services = @(
    @{
        Name = "scoutify-ui-host"
        RelativePath = "scoutify"
        BuildType = "npm"
        Dockerfile = "Dockerfile"
        ImageVarName = "scoutify_api_image"
        DefaultImage = "scoutify-ui-host:local"
    },
    @{
        Name = "scoutify-auth-api"
        RelativePath = "scoutify-auth-api"
        BuildType = "dotnet"
        ProjectFile = "scoutify-auth-api.csproj"
        Dockerfile = "Dockerfile"
        ImageVarName = "auth_api_image"
        DefaultImage = "scoutify-auth-api:local"
    },
    @{
        Name = "scoutify-features-api"
        RelativePath = "scoutify-features-api"
        BuildType = "dotnet"
        ProjectFile = "scoutify-features-api.csproj"
        Dockerfile = "Dockerfile"
        ImageVarName = "features_api_image"
        DefaultImage = "scoutify-features-api:local"
    },
    @{
        Name = "scoutify-stocks-api"
        RelativePath = "scoutify-core-api\core-gateway-api"
        BuildType = "dotnet"
        ProjectFile = "scoutify-core-api.csproj"
        Dockerfile = "Dockerfile"
        ImageVarName = "stocks_api_image"
        DefaultImage = "scoutify-stocks-api:local"
    },
    @{
        Name = "scoutify-edge-gateway"
        RelativePath = "scoutify-edge-gateway"
        BuildType = "dotnet"
        ProjectFile = "scoutify-edge-gateway.csproj"
        Dockerfile = "Dockerfile"
        ImageVarName = "edge_gateway_image"
        DefaultImage = "scoutify-edge-gateway:local"
    },
    @{
        Name = "ai-analysis-worker"
        RelativePath = "scoutify-ai-analysis-service\ai-analysis-worker"
        BuildType = "dotnet"
        ProjectFile = "ai-analysis-worker.csproj"
        Dockerfile = "Dockerfile"
        ImageVarName = "ai_worker_image"
        DefaultImage = "ai-analysis-worker:local"
    }
)

$resolvedServices = @()
foreach ($svc in $services) {
    $svcPath = Join-Path $repoRoot $svc.RelativePath
    if (-not (Test-Path $svcPath)) {
        throw "Service path not found: $svcPath"
    }

    $dockerfilePath = Join-Path $svcPath $svc.Dockerfile
    if (-not (Test-Path $dockerfilePath)) {
        throw "Dockerfile not found for service '$($svc.Name)': $dockerfilePath"
    }

    $serviceFolder = Join-Path $imagesRoot $svc.Name
    New-Item -ItemType Directory -Path $serviceFolder -Force | Out-Null

    $metadataFile = Join-Path $serviceFolder "service-info.txt"
    @(
        "name=$($svc.Name)"
        "path=$svcPath"
        "buildType=$($svc.BuildType)"
        "dockerfile=$dockerfilePath"
    ) | Set-Content -Path $metadataFile -Encoding utf8

    $resolvedServices += [PSCustomObject]@{
        Name = $svc.Name
        ServicePath = $svcPath
        BuildType = $svc.BuildType
        ProjectFile = $svc.ProjectFile
        Dockerfile = $dockerfilePath
        ImageVarName = $svc.ImageVarName
        ImageTag = Get-EnvValue -Names @(
            ("SCOUTIFY_{0}" -f $svc.ImageVarName.ToUpper()),
            $svc.ImageVarName.ToUpper()
        ) -DefaultValue $svc.DefaultImage
        ImageTarPath = Join-Path $serviceFolder ($svc.Name + ".tar")
    }
}

if ($resolvedServices.BuildType -contains "npm") {
    Require-Command "npm"
}

$jwtSigningKey = Get-EnvValue -Names @("JWT_SIGNING_KEY", "SCOUTIFY_JWT_SIGNING_KEY") -Required
$googleClientId = Get-EnvValue -Names @("GOOGLE_CLIENT_ID", "SCOUTIFY_GOOGLE_CLIENT_ID") -Required
$openAiApiKey = Get-EnvValue -Names @("OPENAI_API_KEY", "SCOUTIFY_OPENAI_API_KEY") -Required
$alphaVantageApiKey = Get-EnvValue -Names @("ALPHAVANTAGE_API_KEY", "ALPHA_VANTAGE_API_KEY", "SCOUTIFY_ALPHAVANTAGE_API_KEY") -Required
$finnhubApiKey = Get-EnvValue -Names @("FINNHUB_API_KEY", "SCOUTIFY_FINNHUB_API_KEY") -Required
$viteGoogleClientId = Get-EnvValue -Names @("VITE_GOOGLE_CLIENT_ID", "GOOGLE_CLIENT_ID", "SCOUTIFY_GOOGLE_CLIENT_ID") -Required
$serviceBusConnectionString = Get-EnvValue -Names @("SERVICE_BUS_CONNECTION_STRING", "SCOUTIFY_SERVICE_BUS_CONNECTION_STRING") -DefaultValue ""
$keyVaultUri = Get-EnvValue -Names @("KEY_VAULT_URI", "KEYVAULT_VAULT_URL", "SCOUTIFY_KEY_VAULT_URI") -DefaultValue "local://"
$localVaultAddress = Get-EnvValue -Names @("LOCAL_VAULT_ADDRESS", "SCOUTIFY_LOCAL_VAULT_ADDRESS") -DefaultValue "http://vault.scoutify.svc.cluster.local:8200"
$localVaultRootToken = Get-EnvValue -Names @("LOCAL_VAULT_ROOT_TOKEN", "SCOUTIFY_LOCAL_VAULT_ROOT_TOKEN") -DefaultValue "root"

Write-Host ""
Write-Host "Switching kubectl context to '$KubeContext'..." -ForegroundColor Yellow
& kubectl config use-context $KubeContext | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to switch kubectl context to '$KubeContext'."
}

if (-not (kubectl get namespace $Namespace -o name 2>$null)) {
    Write-Host "Creating namespace '$Namespace'..."
    & kubectl create namespace $Namespace | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create namespace '$Namespace'."
    }
}

if (-not $SkipBuild) {
    foreach ($svc in $resolvedServices) {
        Write-Host ""
        Write-Host "== Building $($svc.Name) ($($svc.BuildType)) ==" -ForegroundColor Green

        if ($svc.BuildType -eq "dotnet") {
            $projectPath = Join-Path $svc.ServicePath $svc.ProjectFile
            if (-not (Test-Path $projectPath)) {
                throw "Project file not found for $($svc.Name): $projectPath"
            }

            Invoke-Checked -FilePath "dotnet" -ArgumentList @("restore", $projectPath) -WorkingDirectory $svc.ServicePath
            Invoke-Checked -FilePath "dotnet" -ArgumentList @("build", $projectPath, "-c", "Release", "--no-restore") -WorkingDirectory $svc.ServicePath
        }
        elseif ($svc.BuildType -eq "npm") {
            if (-not (Test-Path (Join-Path $svc.ServicePath "package.json"))) {
                throw "package.json not found for $($svc.Name): $($svc.ServicePath)"
            }
            Invoke-Checked -FilePath "npm" -ArgumentList @("ci") -WorkingDirectory $svc.ServicePath
            Invoke-Checked -FilePath "npm" -ArgumentList @("run", "build") -WorkingDirectory $svc.ServicePath
        }
        else {
            throw "Unsupported build type for $($svc.Name): $($svc.BuildType)"
        }

        Write-Host "Building Docker image: $($svc.ImageTag)"
        $dockerBuildArgs = @(
            "build",
            "-f", $svc.Dockerfile,
            "-t", $svc.ImageTag
        )
        if ($svc.Name -eq "scoutify-ui-host") {
            $dockerBuildArgs += @("--build-arg", "VITE_GOOGLE_CLIENT_ID=$viteGoogleClientId")
        }
        $dockerBuildArgs += $svc.ServicePath
        Invoke-Checked -FilePath "docker" -ArgumentList $dockerBuildArgs -WorkingDirectory $repoRoot

        Write-Host "Saving image archive: $($svc.ImageTarPath)"
        Invoke-Checked -FilePath "docker" -ArgumentList @("save", "-o", $svc.ImageTarPath, $svc.ImageTag) -WorkingDirectory $repoRoot
    }
}
else {
    Write-Host "Skipping service builds because -SkipBuild was specified." -ForegroundColor Yellow
}

$infraTfvarsPath = Join-Path $terraformVarsDir ("infra.{0}.auto.tfvars" -f $EnvironmentName)
$servicesTfvarsPath = Join-Path $terraformVarsDir ("services.{0}.auto.tfvars" -f $EnvironmentName)

$infraTfvars = @(
    "deployment_local = true"
    "environment = $(Escape-TfvarsValue $EnvironmentName)"
)
$infraTfvars | Set-Content -Path $infraTfvarsPath -Encoding utf8

$imageMap = @{}
foreach ($svc in $resolvedServices) {
    $imageMap[$svc.ImageVarName] = $svc.ImageTag
}

$servicesTfvars = @(
    "deployment_local = true"
    "namespace = $(Escape-TfvarsValue $Namespace)"
    "kubeconfig_path = $(Escape-TfvarsValue (Join-Path $env:USERPROFILE ".kube\config"))"
    "kubeconfig_context = $(Escape-TfvarsValue $KubeContext)"
    "jwt_signing_key = $(Escape-TfvarsValue $jwtSigningKey)"
    "google_client_id = $(Escape-TfvarsValue $googleClientId)"
    "openai_api_key = $(Escape-TfvarsValue $openAiApiKey)"
    "alphavantage_api_key = $(Escape-TfvarsValue $alphaVantageApiKey)"
    "finnhub_api_key = $(Escape-TfvarsValue $finnhubApiKey)"
    "key_vault_uri = $(Escape-TfvarsValue $keyVaultUri)"
    "service_bus_connection_string = $(Escape-TfvarsValue $serviceBusConnectionString)"
    "local_vault_address = $(Escape-TfvarsValue $localVaultAddress)"
    "local_vault_root_token = $(Escape-TfvarsValue $localVaultRootToken)"
    "scoutify_api_image = $(Escape-TfvarsValue $imageMap['scoutify_api_image'])"
    "auth_api_image = $(Escape-TfvarsValue $imageMap['auth_api_image'])"
    "features_api_image = $(Escape-TfvarsValue $imageMap['features_api_image'])"
    "stocks_api_image = $(Escape-TfvarsValue $imageMap['stocks_api_image'])"
    "edge_gateway_image = $(Escape-TfvarsValue $imageMap['edge_gateway_image'])"
    "ai_worker_image = $(Escape-TfvarsValue $imageMap['ai_worker_image'])"
)
$servicesTfvars | Set-Content -Path $servicesTfvarsPath -Encoding utf8

$infraDir = Join-Path $deploymentDir "infrastructure\terraform"
$servicesDir = Join-Path $deploymentDir "services\terraform"
$infraStatePath = Join-Path $terraformStateDir ("infra.{0}.tfstate" -f $EnvironmentName)
$servicesStatePath = Join-Path $terraformStateDir ("services.{0}.tfstate" -f $EnvironmentName)

Write-Host ""
Write-Host "== Skipping infrastructure Terraform in local mode ==" -ForegroundColor Cyan
Write-Host "Reason: local desktop deploy uses in-cluster RabbitMQ/Redis/Vault and does not need Azure resources."
Write-Host "Infra tfvars snapshot still written to: $infraTfvarsPath"
if (-not (Test-Path $infraStatePath)) {
    Set-Content -Path $infraStatePath -Value "Local mode: infrastructure apply skipped." -Encoding utf8
}

Write-Host ""
Write-Host "== Applying services Terraform (local mode) ==" -ForegroundColor Cyan
Invoke-WithRetry -FilePath "terraform" -ArgumentList @("init") -WorkingDirectory $servicesDir

# If namespace already exists, import it into this state file so apply is idempotent.
$existingNamespace = & kubectl get namespace $Namespace -o name --ignore-not-found 2>$null
if (-not [string]::IsNullOrWhiteSpace($existingNamespace)) {
    Write-Host "Namespace '$Namespace' already exists. Importing into Terraform state if needed..." -ForegroundColor Yellow

    $namespaceInState = $false
    try {
        Push-Location $servicesDir
        $stateList = & terraform state list "-state=$servicesStatePath" 2>$null
        if ($LASTEXITCODE -eq 0 -and $stateList -contains "kubernetes_namespace.scoutify") {
            $namespaceInState = $true
        }
    }
    finally {
        Pop-Location
    }

    if ($namespaceInState) {
        Write-Host "Namespace is already tracked in Terraform state; import skipped." -ForegroundColor Yellow
    }
    else {
        Invoke-Checked -FilePath "terraform" -ArgumentList @(
            "import",
            "-state=$servicesStatePath",
            "-var-file=$servicesTfvarsPath",
            "kubernetes_namespace.scoutify",
            $Namespace
        ) -WorkingDirectory $servicesDir
    }
}

Invoke-Checked -FilePath "terraform" -ArgumentList @(
    "apply",
    "-auto-approve",
    "-state=$servicesStatePath",
    "-var-file=$servicesTfvarsPath"
) -WorkingDirectory $servicesDir

Seed-LocalVaultSecrets -Namespace $Namespace -VaultToken $localVaultRootToken -SecretMap @{
    "openai-api-key" = $openAiApiKey
    "alpha-vantage"  = $alphaVantageApiKey
    "finnhub"        = $finnhubApiKey
}

Write-Host ""
Write-Host "Restarting AI worker to pick up fresh Vault secrets..." -ForegroundColor Cyan
Invoke-Checked -FilePath "kubectl" -ArgumentList @("rollout", "restart", "deployment/ai-analysis-worker", "-n", $Namespace) -WorkingDirectory $repoRoot
Wait-ForDeploymentReady -Namespace $Namespace -DeploymentName "ai-analysis-worker"

Write-Host ""
Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "Image archives: $imagesRoot"
Write-Host "Terraform state files:"
Write-Host "  $infraStatePath"
Write-Host "  $servicesStatePath"
Write-Host "Terraform var snapshots:"
Write-Host "  $infraTfvarsPath"
Write-Host "  $servicesTfvarsPath"
