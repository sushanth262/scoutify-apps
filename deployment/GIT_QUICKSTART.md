# ⚡ Git Quick Start

Get your deployment configuration on GitHub in 5 minutes!

## 🚀 Quick Setup (PowerShell)

```powershell
# 1. Navigate to deployment directory
cd ScoutifyApps/deployment

# 2. Run setup script
.\setup-git.ps1

# 3. Create GitHub repository (go to https://github.com/new)
#    - Name: scoutify-deployment
#    - Set to Private (recommended)
#    - Do NOT initialize with README

# 4. Add remote and push
git remote add origin https://github.com/YOUR_USERNAME/scoutify-deployment.git
git add .
git commit -m "Initial commit: Scoutify deployment configuration"
git push -u origin main
```

## 🔒 Security Checklist

Before pushing, verify:

- ✅ No `*.tfvars` files with actual secrets
- ✅ No `.env` files
- ✅ No `*.tfstate` files
- ✅ All sensitive files are in `.gitignore`

## 📝 Example Files

The repository includes `.example` files for configuration:

- `infrastructure/terraform/environments/dev/terraform.tfvars.example`
- `services/terraform/environments/dev/terraform.tfvars.example`

**Copy these and add your actual values locally** (the `.tfvars` files are gitignored).

## 🔐 Managing Secrets

### Option 1: Environment Variables
```powershell
$env:GITHUB_TOKEN = "ghp_your_token_here"
$env:SERVICE_BUS_CONNECTION_STRING = "your_connection_string"
```

### Option 2: Local tfvars (Gitignored)
```powershell
# Copy example file
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit with your secrets (this file won't be committed)
```

## 📚 More Information

- [Detailed Git Guide](./README_GIT.md)
- [Git Setup Instructions](./SETUP_GIT.md)
- [GitHub Registry Setup](./GITHUB_REGISTRY_SETUP.md)

