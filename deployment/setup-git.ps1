# PowerShell script to set up Git repository for deployment
# Usage: .\setup-git.ps1

Write-Host "🚀 Setting up Git repository for Scoutify deployment..." -ForegroundColor Cyan

# Check if Git is installed
try {
    $gitVersion = git --version
    Write-Host "✅ Git is installed: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Git is not installed. Please install Git first." -ForegroundColor Red
    exit 1
}

# Initialize Git repository
if (Test-Path .git) {
    Write-Host "⚠️  Git repository already initialized" -ForegroundColor Yellow
} else {
    Write-Host "📦 Initializing Git repository..." -ForegroundColor Cyan
    git init
    Write-Host "✅ Git repository initialized" -ForegroundColor Green
}

# Check for .gitignore
if (Test-Path .gitignore) {
    Write-Host "✅ .gitignore file exists" -ForegroundColor Green
} else {
    Write-Host "⚠️  .gitignore file not found" -ForegroundColor Yellow
}

# Check for example files
$exampleFiles = Get-ChildItem -Recurse -Filter "*.tfvars.example" -ErrorAction SilentlyContinue
if ($exampleFiles) {
    Write-Host "✅ Example files found: $($exampleFiles.Count) files" -ForegroundColor Green
} else {
    Write-Host "⚠️  No example files found. Creating them..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "1. Create a GitHub repository at https://github.com/new" -ForegroundColor White
Write-Host "2. Add remote: git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git" -ForegroundColor White
Write-Host "3. Stage files: git add ." -ForegroundColor White
Write-Host "4. Commit: git commit -m 'Initial commit: Scoutify deployment'" -ForegroundColor White
Write-Host "5. Push: git push -u origin main" -ForegroundColor White
Write-Host ""
Write-Host "📚 See SETUP_GIT.md for detailed instructions" -ForegroundColor Cyan

