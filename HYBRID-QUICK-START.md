# Quick Start: Hybrid GitHub + Personal Azure DevOps

Your Configuration:
- **GitHub:** https://github.com/aoredo/deploy-vwan
- **Azure DevOps:** https://dev.azure.com/darockProjects/vwan-deploy
- **Pluralsight Lab:** Subscription ID `2213e8b1-dbc7-4d54-8aff-b5e315df5e5b`

---

## ⚡ 5-Minute Setup

### Step 1: Run Setup Script
```bash
cd /Users/aoredope/deploy-vwan
chmod +x scripts/setup_personal_ado.sh
./scripts/setup_personal_ado.sh \
  "https://dev.azure.com/darockProjects" \
  "vwan-deploy" \
  "https://github.com/aoredo/deploy-vwan"
```

This creates variable groups in your personal Azure DevOps automatically.

### Step 2: Push to GitHub
```bash
git remote add github https://github.com/aoredo/deploy-vwan.git
git push -u github main
git push -u github ea-np
git push -u github ea-prd
```

### Step 3: Create Pipeline in Azure DevOps
1. Go to: https://dev.azure.com/darockProjects/vwan-deploy/_build
2. Click **Create Pipeline**
3. Select **GitHub**
4. Authorize GitHub and select **aoredo/deploy-vwan**
5. Choose **Existing Azure Pipelines YAML file**
6. Path: `azure-pipelines.yml`
7. Click **Save and run**

### Step 4: Link Variable Groups
1. Go to Pipeline Settings (gear icon)
2. Scroll to **Variable groups**
3. Add: `vwan-nonprod-vars` and `vwan-prod-vars`

---

## 🚀 Test the Workflow

### Deploy to Non-Prod (Auto)
```bash
git checkout ea-np
echo "# Test" >> DEVOPS-SETUP-CHECKLIST.md
git add .
git commit -m "Test non-prod deployment"
git push github ea-np
```
Watch: https://dev.azure.com/darockProjects/vwan-deploy/_build

### Deploy to Production (Manual Approval)
```bash
git checkout ea-prd
git merge ea-np
git push github ea-prd
# Approve in Azure DevOps console
```

---

## 📚 Full Documentation

- `HYBRID-SETUP.md` - Complete setup guide
- `BRANCHING-STRATEGY.md` - Two-branch workflow details
- `azure-pipelines.yml` - Pipeline configuration

---

## ✅ All Set!

Your infrastructure is now ready to deploy through:
- Your personal Git workflow (GitHub)
- Your personal CI/CD (Azure DevOps)
- Pluralsight lab resources (Azure subscription)

Start by running: `./scripts/setup_personal_ado.sh`
