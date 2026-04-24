# 🚀 Git Setup Instructions

Quick guide to set up Git and push to GitHub.

## 📋 Step-by-Step Setup

### 1. Initialize Git (if not already done)

```bash
cd ScoutifyApps/deployment
git init
```

### 2. Configure Git (if needed)

```bash
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### 3. Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `scoutify-deployment` (or your preferred name)
3. Description: "Scoutify deployment configuration with Terraform"
4. Set to **Private** (recommended for deployment configs)
5. **Do NOT** initialize with README, .gitignore, or license
6. Click **Create repository**

### 4. Add Remote and Push

```bash
# Add remote (replace with your username)
git remote add origin https://github.com/your-username/scoutify-deployment.git

# Or use SSH (if you have SSH keys set up):
# git remote add origin git@github.com:your-username/scoutify-deployment.git

# Stage all files
git add .

# Commit
git commit -m "Initial commit: Scoutify deployment configuration"

# Push to GitHub
git push -u origin main

# If your default branch is 'master' instead of 'main':
# git push -u origin master
```

## 🔒 Important Security Notes

### ✅ Safe to Commit
- All `.tf` files (Terraform configuration)
- `.tfvars.example` files (templates)
- Documentation (`.md` files)
- Scripts (`.sh` files)
- Kubernetes manifests (`.yaml` files)

### ❌ Never Commit
- `*.tfvars` files with actual secrets (these are gitignored)
- `.env` files
- `*.tfstate` files
- Any files with tokens, passwords, or keys

## 📝 Working with Example Files

The repository includes `.example` files that are safe to commit:

```bash
# Use the example file as a template
cp infrastructure/terraform/environments/dev/terraform.tfvars.example \
   infrastructure/terraform/environments/dev/terraform.tfvars

# Edit terraform.tfvars with your actual values (this file is gitignored)
# Never commit terraform.tfvars with secrets!
```

## 🔄 Daily Workflow

### Making Changes

```bash
# 1. Make your changes
# 2. Check what will be committed
git status

# 3. Stage changes
git add .

# 4. Commit with descriptive message
git commit -m "Add: Description of your changes"

# 5. Push to GitHub
git push
```

### Creating Branches

```bash
# Create and switch to new branch
git checkout -b feature/your-feature-name

# Make changes, commit, then push
git push -u origin feature/your-feature-name

# Create pull request on GitHub
# After merge, switch back to main
git checkout main
git pull
```

## 🔐 Managing Secrets

### Option 1: Environment Variables

```bash
# Set secrets as environment variables
export GITHUB_TOKEN=ghp_your_token_here
export SERVICE_BUS_CONNECTION_STRING=your_connection_string

# Reference in Terraform
github_token = var.github_token
```

### Option 2: Local tfvars (Gitignored)

```bash
# Create local file (not committed)
cp terraform.tfvars.example terraform.tfvars
# Edit with your secrets
terraform apply -var-file=terraform.tfvars
```

### Option 3: Terraform Cloud

Store secrets in Terraform Cloud variables (encrypted at rest).

## 🆘 Troubleshooting

### Already Have a Git Repository?

If the parent directory already has Git:

```bash
# Check if deployment is already tracked
cd ScoutifyApps
git status

# If deployment is tracked, you can either:
# 1. Keep it in the parent repo (recommended)
# 2. Create a separate repo for deployment (use git submodule)
```

### Authentication Issues

**HTTPS:**
```bash
# Use GitHub Personal Access Token
git remote set-url origin https://YOUR_TOKEN@github.com/username/repo.git
```

**SSH:**
```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to GitHub: Settings → SSH and GPG keys
# Test connection
ssh -T git@github.com
```

### Large Files

If you have large files:
```bash
# Install Git LFS
git lfs install

# Track large files
git lfs track "*.zip"
git lfs track "*.tar.gz"
```

## 📚 Next Steps

1. ✅ Set up Git repository
2. ✅ Create GitHub repository
3. ✅ Push initial code
4. 📝 Update `.tfvars.example` files with your values
5. 🔐 Set up secrets (environment variables or Terraform Cloud)
6. 🚀 Start deploying!

## 🔗 Related Documentation

- [Git README](./README_GIT.md) - Detailed Git guide
- [GitHub Registry Setup](./GITHUB_REGISTRY_SETUP.md) - GHCR configuration
- [GitHub Credentials](./GITHUB_CREDENTIALS.md) - Credentials reference

