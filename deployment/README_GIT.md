# 📦 Git Repository Setup

This guide explains how to set up and maintain the deployment repository in Git.

## 🚀 Initial Setup

### 1. Initialize Git (if not already done)

```bash
cd ScoutifyApps/deployment
git init
```

### 2. Add Remote Repository

```bash
git remote add origin https://github.com/your-username/scoutify-deployment.git
# Or use SSH:
# git remote add origin git@github.com:your-username/scoutify-deployment.git
```

### 3. First Commit

```bash
# Stage all files
git add .

# Commit
git commit -m "Initial commit: Scoutify deployment configuration"

# Push to GitHub
git push -u origin main
# Or if your default branch is master:
# git push -u origin master
```

## 🔒 What Should NOT Be Committed

The `.gitignore` file excludes the following sensitive files:

### ❌ Never Commit

- **Terraform state files** (`*.tfstate`, `*.tfstate.*`)
- **Terraform variables with secrets** (`*.tfvars` files with tokens)
- **Environment files** (`.env`, `.env.local`)
- **Sensitive credentials** (tokens, keys, passwords)
- **Infrastructure outputs** (`infrastructure-outputs.json`)

### ✅ Safe to Commit

- **Terraform configuration** (`.tf` files)
- **Example tfvars** (`terraform.tfvars.example`)
- **Documentation** (`.md` files)
- **Scripts** (`.sh` files)
- **Kubernetes manifests** (`.yaml` files)

## 📝 Working with Sensitive Variables

### Option 1: Use Example Files (Recommended)

Create example files without secrets:

```bash
# Copy example file
cp environments/dev/terraform.tfvars.example environments/dev/terraform.tfvars

# Edit with your values (this file is gitignored)
# Never commit the actual terraform.tfvars with secrets
```

### Option 2: Use Environment Variables

Set secrets as environment variables:

```bash
export GITHUB_TOKEN=ghp_your_token_here
export SERVICE_BUS_CONNECTION_STRING=your_connection_string
```

Then reference in Terraform:
```hcl
github_token = var.github_token  # From environment
```

### Option 3: Use Terraform Cloud/Enterprise

Store secrets in Terraform Cloud variables (encrypted).

## 🔐 Creating Example Files

Create example files for others to use:

```bash
# Infrastructure
cp infrastructure/terraform/environments/dev/terraform.tfvars \
   infrastructure/terraform/environments/dev/terraform.tfvars.example

# Services
cp services/terraform/environments/dev/terraform.tfvars \
   services/terraform/environments/dev/terraform.tfvars.example

# Remove sensitive values from example files
# Then commit the .example files
```

## 📋 Recommended Repository Structure

```
scoutify-deployment/
├── .gitignore              # Git ignore rules
├── .gitattributes          # Git attributes
├── README.md               # Main README
├── README_GIT.md           # This file
├── infrastructure/
│   └── terraform/
│       └── environments/
│           └── dev/
│               ├── terraform.tfvars.example  # ✅ Committed
│               └── terraform.tfvars          # ❌ Gitignored
└── services/
    └── terraform/
        └── environments/
            └── dev/
                ├── terraform.tfvars.example  # ✅ Committed
                └── terraform.tfvars          # ❌ Gitignored
```

## 🚨 Security Checklist

Before committing, verify:

- [ ] No `.tfvars` files with actual secrets
- [ ] No `.env` files
- [ ] No `*.tfstate` files
- [ ] No tokens or passwords in code
- [ ] All sensitive files are in `.gitignore`

## 🔄 Daily Workflow

### Making Changes

```bash
# 1. Make changes to .tf files
# 2. Update example files if needed
# 3. Stage changes
git add *.tf *.md *.sh

# 4. Commit
git commit -m "Update: Description of changes"

# 5. Push
git push
```

### Working with Secrets

```bash
# 1. Create local tfvars (gitignored)
cp terraform.tfvars.example terraform.tfvars

# 2. Edit with your secrets (not committed)
# 3. Use in terraform apply
terraform apply -var-file=terraform.tfvars
```

## 📚 Best Practices

1. **Never commit secrets** - Use example files instead
2. **Review changes before commit** - `git diff` before `git add`
3. **Use descriptive commits** - Clear commit messages
4. **Keep example files updated** - When structure changes
5. **Use branches** - Create feature branches for changes
6. **Review PRs** - Have others review before merging

## 🔗 Related Documentation

- [GitHub Registry Setup](./GITHUB_REGISTRY_SETUP.md)
- [GitHub Credentials](./GITHUB_CREDENTIALS.md)
- [Terraform README](./terraform/README.md)

## 🆘 Troubleshooting

### Accidentally Committed Secrets

If you accidentally committed secrets:

1. **Remove from history** (dangerous if already pushed):
   ```bash
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/file" \
     --prune-empty --tag-name-filter cat -- --all
   ```

2. **Rotate secrets** - Change all exposed credentials immediately

3. **Use git-secrets** - Install tool to prevent future commits:
   ```bash
   git secrets --install
   git secrets --register-aws
   ```

### Large Files

If you have large files:
```bash
# Use Git LFS
git lfs install
git lfs track "*.zip"
git lfs track "*.tar.gz"
```

## 📝 Example .tfvars File Structure

### terraform.tfvars (Gitignored - Your Actual Values)
```hcl
github_token = "ghp_actual_token_here"
service_bus_connection_string = "Endpoint=sb://actual-connection-string"
```

### terraform.tfvars.example (Committed - Template)
```hcl
github_token = ""  # Set your GitHub Personal Access Token
service_bus_connection_string = ""  # Set your Service Bus connection string
```

