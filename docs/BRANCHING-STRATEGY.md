# Git Branching Strategy for vWAN Deployment

## Overview

This project uses a **two-environment branching strategy** with automated promotion from non-production to production.

```
┌─────────────────────────────────────────────────────────┐
│ Feature Branch (feature/*)                              │
│ - Development and testing                               │
│ - Create PR to ea-np                                    │
└────────────────┬────────────────────────────────────────┘
                 │ PR Review & Merge
                 ▼
┌─────────────────────────────────────────────────────────┐
│ ea-np Branch (Non-Production / Development)             │
│ - Staging environment                                   │
│ - ✅ Auto-deploys on push (no approval needed)          │
│ - Tests new features                                    │
│ - Type: Development/Testing                             │
└────────────────┬────────────────────────────────────────┘
                 │ Code Review + Promotion
                 │ (Create PR to ea-prd)
                 ▼
┌─────────────────────────────────────────────────────────┐
│ ea-prd Branch (Production)                              │
│ - Production environment                                │
│ - ⏳ Requires manual approval before deploy              │
│ - Runs only when code tested in ea-np                   │
│ - Type: Production                                      │
└─────────────────────────────────────────────────────────┘
```

## Branches

### `ea-np` - Non-Production (Development/Testing)

**Purpose:** Test all new features and changes before production

**Deployment:**
- ✅ Automatic deployment on every push
- ❌ No approval required
- ⏱️ Deploys in ~20 minutes

**Environment:**
- Resource Group: `rg-vwan-nonprod`
- Firewall: `afw-nonprod-eastus` (Standard tier)
- State: `vwan-nonprod/terraform.tfstate`

**Use for:**
- Testing new firewall rules
- Validating network configurations
- Experimenting with infrastructure changes
- Training and demos

### `ea-prd` - Production

**Purpose:** Production infrastructure with quality gates

**Deployment:**
- ⏳ Requires manual approval
- 👥 Only approved users can deploy
- ⏱️ Deploys in ~20 minutes (after approval)

**Environment:**
- Resource Group: `rg-vwan-prd`
- Firewall: `afw-prd-eastus` (Premium tier)
- State: `vwan-prd/terraform.tfstate`

**Use for:**
- Production workloads
- Stable, tested configurations
- Business-critical infrastructure

## Workflow

### Step 1: Create Feature Branch

```bash
# Create feature branch from ea-np
git checkout ea-np
git pull origin ea-np
git checkout -b feature/add-sql-rules

# Make changes
nano firewall.tf
# ... edit firewall rules ...

# Commit changes
git add .
git commit -m "Add SQL database firewall rules for new app"
```

### Step 2: Test in Non-Production

```bash
# Push feature branch
git push -u origin feature/add-sql-rules

# Create Pull Request to ea-np
# Go to Azure DevOps/GitHub → Create PR
# - From: feature/add-sql-rules
# - To: ea-np

# Pipeline runs automatically:
# ✓ Terraform format check
# ✓ Syntax validation
# ✓ Plan generation (shows plan in PR)
# ✓ Security scanning
```

### Step 3: Review and Merge to ea-np

```bash
# Test results
# ✓ Plan shows expected changes
# ✓ No security issues
# ✓ Code review approved

# Merge PR to ea-np
# → Pipeline automatically deploys to nonprod
# → Firewall rules applied
# → Can be tested immediately
```

### Step 4: Validate in Non-Production

```bash
# Test deployed changes in nonprod environment
# - Test connectivity
# - Verify firewall rules
# - Validate application behavior
# - Check logs

az firewall policy rule collection list \
  --resource-group rg-vwan-nonprod \
  --firewall-policy afw-nonprod-policy \
  --output table
```

### Step 5: Promote to Production

Once validated in nonprod, create PR to production:

```bash
# Create PR from ea-np to ea-prd
# Go to Azure DevOps/GitHub → Create PR
# - From: ea-np
# - To: ea-prd
# - Title: "Prod: Add SQL firewall rules"
# - Description: Link to nonprod PR, testing results

# Pipeline validates:
# ✓ Terraform format check
# ✓ Syntax validation
# ✓ Plan generation (shows plan in PR)
# ✓ Security scanning
# → Waits for approval
```

### Step 6: Approve and Deploy to Production

```bash
# Approver reviews PR and plan
# - Verifies changes are correct
# - Checks nonprod test results
# - Ensures no breaking changes

# Approve PR
# → Azure DevOps environment approval triggers
# → Need 2 approvals required for production
# → Infrastructure deployed to ea-prd

# Verify production deployment
az firewall policy rule collection list \
  --resource-group rg-vwan-prd \
  --firewall-policy afw-prd-policy \
  --output table
```

## Environment Configuration

### Non-Production (ea-np)

**terraform.tfvars:**
```hcl
resource_group_name = "rg-vwan-nonprod"
vwan_name           = "vwan-nonprod-eastus"
vhub_name           = "vhub-nonprod-eastus"
firewall_name       = "afw-nonprod-eastus"
firewall_sku_tier   = "Standard"  # Cost-effective for testing

tags = {
  Environment = "nonproduction"
  CostCenter  = "IT-Development"
  Type        = "Testing"
}
```

### Production (ea-prd)

**terraform.tfvars:**
```hcl
resource_group_name = "rg-vwan-prd"
vwan_name           = "vwan-prd-eastus"
vhub_name           = "vhub-prd-eastus"
firewall_name       = "afw-prd-eastus"
firewall_sku_tier   = "Premium"  # Enhanced security for production

tags = {
  Environment = "production"
  CostCenter  = "IT-Operations"
  Type        = "Production"
}
```

## Pipeline Stages by Branch

### Pull Requests (Any Branch)

```
Validate
├─ Terraform format check
├─ Syntax validation
└─ Plan preview
```

### ea-np Push (Non-Production Deploy)

```
✓ Validate
✓ Security Scan
✅ Apply (Auto-deploy, no approval)
✓ Post-Deploy Validation
```

### ea-prd Push (Production Deploy)

```
✓ Validate
✓ Security Scan
⏳ Apply (Requires approval)
   ├─ Display plan
   ├─ Wait for approval
   └─ Deploy if approved
✓ Post-Deploy Validation
```

## Best Practices

### ✅ DO

- ✅ Always create feature branches from `ea-np`
- ✅ Use PR review before merging to `ea-np`
- ✅ Test thoroughly in nonprod before promoting to prod
- ✅ Include testing notes in PR descriptions
- ✅ Use descriptive branch names: `feature/add-rules`, `fix/firewall-bug`
- ✅ Keep commits focused and meaningful
- ✅ Review CI/CD plan output before approving
- ✅ Document changes in PR description
- ✅ Require 2 approvals for production changes
- ✅ Block direct commits to `ea-prd` and `ea-np`

### ❌ DON'T

- ❌ Skip testing in nonprod before promoting to prod
- ❌ Force push to `ea-np` or `ea-prd`
- ❌ Commit directly to protected branches
- ❌ Make emergency prod changes without approval
- ❌ Merge PRs without code review
- ❌ Ignore security scan warnings
- ❌ Deploy untested infrastructure
- ❌ Mix feature branches with different purposes
- ❌ Use temporary branches for production changes
- ❌ Ignore pipeline failures

## Protecting the Branches

### Branch Protection Policies

Enforce standards on both branches:

```
Branch: ea-np
├─ Require pull request reviews
├─ Require minimum 1 reviewer
├─ Dismiss stale approvals: OFF (allow rebases)
├─ Require status checks to pass
└─ Restrict who can push (maintainers only)

Branch: ea-prd
├─ Require pull request reviews
├─ Require minimum 2 reviewers ← Production standard
├─ Require code owners review
├─ Require status checks to pass
├─ Require up-to-date branches
└─ Restrict who can push (admins only)
```

### Implement via Azure DevOps

1. **Project Settings** → **Repositories**
2. Select `deploy-vwan`
3. **Policies** → **Branch Policies** → Select branch
4. Configure:
   - ✓ Require pull request reviews
   - ✓ Set minimum reviewers
   - ✓ Check for linked work items
   - ✓ Require successful builds

## Hotfixes (Emergency Production Changes)

For critical production issues:

```bash
# Create hotfix branch from ea-prd
git checkout ea-prd
git pull origin ea-prd
git checkout -b hotfix/critical-firewall-rule

# Make fix
nano firewall.tf

# Commit
git add .
git commit -m "Fix: Critical firewall rule for down service"

# Push
git push -u origin hotfix/critical-firewall-rule

# Create PR to ea-prd with label "CRITICAL"
# - Requires immediate review
# - Deploy immediately after approval
# - Document incident

# After merging to ea-prd:
# Also merge back to ea-np to stay in sync
git checkout ea-np
git pull origin ea-prd
git push origin ea-np
```

## Monitoring and Alerting

### Check Deployment Status

```bash
# View recent pipelines
az pipelines runs list --top 10

# Check specific branch status
az pipelines runs list --definitions azure-pipelines.yml --branch ea-np --top 5

# Get run details
az pipelines runs show --id RUN_ID
```

### Failed Deployments

If a deployment fails:

1. **Check logs** in Azure DevOps pipeline run
2. **Review error** in "Deploy" stage
3. **Fix issue** locally on feature branch
4. **Re-test** in nonprod
5. **Re-run** pipeline

```bash
# Example: Local testing before retry
terraform plan -var-file=terraform.tfvars
terraform validate

# Fix issues
# Commit and push
git add .
git commit -m "Fix: resolve deployment issue"
git push origin feature/branch-name

# Pipeline automatically retests
```

## Common Scenarios

### Scenario 1: Add Firewall Rule to Both Environments

```bash
# 1. Create feature branch
git checkout -b feature/allow-https

# 2. Edit firewall rules
nano firewall.tf

# 3. Test in ea-np
git push -u origin feature/allow-https
# Create PR to ea-np
# Wait for deployment
# Test in nonprod environment

# 4. Promote to ea-prd
# Create PR from ea-np to ea-prd
# Get approvals
# Deploy to production
```

### Scenario 2: Revert problematic change

```bash
# If production deployment causes issues:

# Create revert branch
git checkout ea-prd
git checkout -b hotfix/revert-bad-change

# Revert commit
git revert COMMIT_HASH

# Push and create emergency PR
git push -u origin hotfix/revert-bad-change
# Create PR to ea-prd with "URGENT" label
# Fast-track approval
# Deploy immediately

# Also update ea-np
git checkout ea-np
git pull
git cherry-pick REVERT_COMMIT_HASH
git push origin ea-np
```

### Scenario 3: Testing multiple changes

```bash
# Organize with feature flags or separate rules

git checkout -b feature/batch-changes

# Multiple related changes
nano firewall.tf  # Add rules
nano network.tf   # Modify networks

# Push as one PR for cohesive testing
git push -u origin feature/batch-changes

# Test together in nonprod
# If all work, promote as one change to prod
```

## Troubleshooting

### PR not showing plan output

```bash
# Check pipeline status
# Go to PR → Checks tab → Azure Pipelines

# If failed:
# 1. Check terraform syntax
# 2. Verify .tfvars file
# 3. Check backend configuration
# 4. Rerun pipeline
```

### Merge conflict between branches

```bash
# If ea-np and ea-prd diverge

# Pull latest
git fetch origin

# Create merge branch
git checkout -b merge/sync-branches
git merge origin/ea-np

# Resolve conflicts
git add .
git commit -m "Merge: sync ea-np to ea-prd"

# Create PR to ea-prd
git push -u origin merge/sync-branches
```

### Keep branches synchronized

```bash
# Periodic sync from ea-np to ea-prd
git checkout ea-prd
git pull origin ea-prd
git pull origin ea-np --ff-only
git push origin ea-prd

# Or create PR for review instead of fast-forward
```

## Reference

| Action | Branch | Approval | Duration |
|--------|--------|----------|----------|
| Create feature | feature/* | N/A | N/A |
| Test changes | PR to ea-np | 1 reviewer | Auto |
| Deploy to nonprod | Merge to ea-np | Auto | ~20 min |
| Promote to prod | PR to ea-prd | 2 reviewers | Auto |
| Deploy to prod | Merge to ea-prd | Auto | ~20 min |
| Emergency fix | hotfix/* to ea-prd | 1-2 reviewers | Immediate |

## Getting Help

- **Pipeline failed?** Check Azure DevOps pipeline run logs
- **Merge conflict?** Use `git mergetool` or GitHub UI
- **Not sure about a change?** Test in nonprod first
- **Need to rollback?** Create hotfix branch and revert changes

---

**Updated:** February 25, 2026
