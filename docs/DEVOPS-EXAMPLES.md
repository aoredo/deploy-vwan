# Azure DevOps Pipeline Examples

## Example 1: Simple Two-Environment Pipelines

For separate pipelines for dev and prod environments.

### File: `azure-pipelines-dev.yml`

```yaml
trigger:
  branches:
    include:
      - develop
  paths:
    include:
      - '*.tf'
      - 'terraform.tfvars'

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.5.0'
  environment: 'dev'
  tfVarsFile: 'terraform.tfvars'

jobs:
  - job: TerraformValidateAndApply
    displayName: 'Terraform Dev Deployment'
    
    variables:
      azureSubscriptionEndpoint: 'Azure-Terraform-SP-Dev'
      
    steps:
      - task: TerraformInstaller@0
        displayName: 'Install Terraform'
        inputs:
          terraformVersion: $(terraformVersion)

      - task: TerraformTaskV3@3
        displayName: 'Terraform Init'
        inputs:
          provider: 'azurerm'
          command: 'init'
          backendServiceArm: $(azureSubscriptionEndpoint)
          backendAzureRmResourceGroupName: 'rg-terraform-state'
          backendAzureRmStorageAccountName: 'stterraformstate'
          backendAzureRmContainerName: 'tfstate-dev'
          backendAzureRmKey: 'vwan-dev/terraform.tfstate'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Validate'
        inputs:
          provider: 'azurerm'
          command: 'validate'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Plan'
        inputs:
          provider: 'azurerm'
          command: 'plan'
          commandOptions: '-out=tfplan -var-file=$(tfVarsFile)'
          environmentServiceNameAzureRM: $(azureSubscriptionEndpoint)

      - script: terraform apply -auto-approve tfplan
        displayName: 'Terraform Apply'
        condition: succeeded()
```

### File: `azure-pipelines-prod.yml`

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - '*.tf'

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.5.0'
  environment: 'prod'

jobs:
  - deployment: TerraformProduction
    displayName: 'Terraform Production Deployment'
    environment: 'Production'
    
    variables:
      azureSubscriptionEndpoint: 'Azure-Terraform-SP-Prod'
      
    strategy:
      runOnce:
        deploy:
          steps:
            - checkout: self
            
            - task: TerraformInstaller@0
              displayName: 'Install Terraform'
              inputs:
                terraformVersion: $(terraformVersion)

            - task: TerraformTaskV3@3
              displayName: 'Terraform Init'
              inputs:
                provider: 'azurerm'
                command: 'init'
                backendServiceArm: $(azureSubscriptionEndpoint)
                backendAzureRmResourceGroupName: 'rg-terraform-state'
                backendAzureRmStorageAccountName: 'stterraformstate'
                backendAzureRmContainerName: 'tfstate'
                backendAzureRmKey: 'vwan/terraform.tfstate'

            - task: TerraformTaskV3@3
              displayName: 'Terraform Plan'
              inputs:
                provider: 'azurerm'
                command: 'plan'
                commandOptions: '-out=tfplan -var-file=terraform.tfvars'
                environmentServiceNameAzureRM: $(azureSubscriptionEndpoint)

            - task: TerraformTaskV3@3
              displayName: 'Terraform Apply'
              inputs:
                provider: 'azurerm'
                command: 'apply'
                commandOptions: '-input=false tfplan'
                environmentServiceNameAzureRM: $(azureSubscriptionEndpoint)
```

---

## Example 2: Multi-Region Deployment

Deploy infrastructure to multiple Azure regions simultaneously.

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.5.0'

strategy:
  matrix:
    EastUS:
      region: 'eastus'
      rgName: 'rg-vwan-prod-east'
      tfStateKey: 'vwan-east/terraform.tfstate'
    WestEurope:
      region: 'westeurope'
      rgName: 'rg-vwan-prod-eu'
      tfStateKey: 'vwan-eu/terraform.tfstate'

jobs:
  - job: DeployPerRegion
    displayName: 'Deploy to $(region)'
    
    steps:
      - task: TerraformInstaller@0
        displayName: 'Install Terraform'
        inputs:
          terraformVersion: $(terraformVersion)

      - task: TerraformTaskV3@3
        displayName: 'Terraform Init'
        inputs:
          provider: 'azurerm'
          command: 'init'
          backendServiceArm: 'Azure-Terraform-SP'
          backendAzureRmResourceGroupName: 'rg-terraform-state'
          backendAzureRmStorageAccountName: 'stterraformstate'
          backendAzureRmContainerName: 'tfstate'
          backendAzureRmKey: $(tfStateKey)

      - task: TerraformTaskV3@3
        displayName: 'Terraform Plan'
        inputs:
          provider: 'azurerm'
          command: 'plan'
          commandOptions: '-var="location=$(region)" -out=tfplan'
          environmentServiceNameAzureRM: 'Azure-Terraform-SP'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Apply'
        inputs:
          provider: 'azurerm'
          command: 'apply'
          commandOptions: '-input=false tfplan'
          environmentServiceNameAzureRM: 'Azure-Terraform-SP'
```

---

## Example 3: Drift Detection Pipeline

Run nightly to detect configuration drift.

```yaml
schedules:
  - cron: "0 2 * * *"  # 2 AM daily
    displayName: Daily Drift Detection
    branches:
      include:
        - main

trigger: none
pr: none

pool:
  vmImage: 'ubuntu-latest'

jobs:
  - job: DriftDetection
    displayName: 'Detect Infrastructure Drift'
    
    steps:
      - task: TerraformInstaller@0
        displayName: 'Install Terraform'
        inputs:
          terraformVersion: '1.5.0'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Init'
        inputs:
          provider: 'azurerm'
          command: 'init'
          backendServiceArm: 'Azure-Terraform-SP'
          backendAzureRmResourceGroupName: 'rg-terraform-state'
          backendAzureRmStorageAccountName: 'stterraformstate'
          backendAzureRmContainerName: 'tfstate'
          backendAzureRmKey: 'vwan/terraform.tfstate'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Refresh'
        inputs:
          provider: 'azurerm'
          command: 'custom'
          customCommand: 'refresh'
          environmentServiceNameAzureRM: 'Azure-Terraform-SP'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Plan (Drift Check)'
        inputs:
          provider: 'azurerm'
          command: 'plan'
          commandOptions: '-detailed-exitcode'
          environmentServiceNameAzureRM: 'Azure-Terraform-SP'
        continueOnError: true

      - script: |
          if [ $? -eq 2 ]; then
            echo "##[warning] Infrastructure drift detected!"
            echo "##vso[task.complete result=SucceededWithIssues;]"
          fi
        displayName: 'Check for Drift'

      - task: SendEmail@1
        displayName: 'Send Drift Alert'
        inputs:
          To: 'devops@company.com'
          Subject: 'Infrastructure Drift Detected'
          Body: 'See pipeline logs for details'
        condition: eq(variables['System.Status'], 'SucceededWithIssues')
```

---

## Example 4: Destroy Pipeline (with Confirmation)

For controlled infrastructure teardown.

```yaml
trigger: none
pr: none

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.5.0'

jobs:
  - job: DestroyInfrastructure
    displayName: 'Destroy Infrastructure'
    
    timeoutInMinutes: 60
    
    variables:
      azureSubscriptionEndpoint: 'Azure-Terraform-SP'
    
    steps:
      - task: TerraformInstaller@0
        displayName: 'Install Terraform'
        inputs:
          terraformVersion: $(terraformVersion)

      - task: TerraformTaskV3@3
        displayName: 'Terraform Init'
        inputs:
          provider: 'azurerm'
          command: 'init'
          backendServiceArm: $(azureSubscriptionEndpoint)
          backendAzureRmResourceGroupName: 'rg-terraform-state'
          backendAzureRmStorageAccountName: 'stterraformstate'
          backendAzureRmContainerName: 'tfstate'
          backendAzureRmKey: 'vwan/terraform.tfstate'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Plan Destroy'
        inputs:
          provider: 'azurerm'
          command: 'plan'
          commandOptions: '-destroy -out=destroy-plan'
          environmentServiceNameAzureRM: $(azureSubscriptionEndpoint)

      - task: PublishBuildArtifacts@1
        displayName: 'Save Destroy Plan'
        inputs:
          pathToPublish: '$(System.DefaultWorkingDirectory)'
          artifactName: 'destroy-plan'

      - task: ManualValidation@0
        displayName: 'Manual Approval - Review Destroy Plan'
        inputs:
          notifyUsers: 'devops@company.com'
          instructions: 'Review the destroy plan. Approve only if correct.'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Destroy'
        inputs:
          provider: 'azurerm'
          command: 'apply'
          commandOptions: '-input=false destroy-plan'
          environmentServiceNameAzureRM: $(azureSubscriptionEndpoint)

      - script: |
          echo "##[warning] Infrastructure has been destroyed!"
          echo "Run: ./scripts/setup_state.sh to redeploy"
        displayName: 'Cleanup Complete'
```

---

## Example 5: Integration Testing Pipeline

With post-deployment validation scripts.

```yaml
trigger:
  branches:
    include:
      - develop

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: Deploy
    displayName: 'Deploy to Dev'
    jobs:
      - job: TerraformApply
        steps:
          - task: TerraformInstaller@0
            inputs:
              terraformVersion: '1.5.0'
          
          - task: TerraformTaskV3@3
            displayName: 'Terraform Apply'
            inputs:
              provider: 'azurerm'
              command: 'apply'
              commandOptions: '-auto-approve'
              environmentServiceNameAzureRM: 'Azure-Terraform-SP'

          - script: |
              terraform output -json > outputs.json
            displayName: 'Export Outputs'

          - task: PublishBuildArtifacts@1
            inputs:
              pathToPublish: 'outputs.json'
              artifactName: 'tf-outputs'

  - stage: Test
    displayName: 'Integration Tests'
    dependsOn: Deploy
    jobs:
      - job: ConnectivityTest
        steps:
          - task: DownloadBuildArtifacts@0
            inputs:
              artifactName: 'tf-outputs'

          - task: AzureCLI@2
            displayName: 'Test Firewall Connectivity'
            inputs:
              azureSubscription: 'Azure-Terraform-SP'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                FW_IP=$(cat outputs.json | jq -r '.firewall_private_ip.value')
                echo "Testing firewall at $FW_IP"
                
                # Test connectivity
                ping -c 1 $FW_IP || echo "Firewall not accessible"

          - task: AzureCLI@2
            displayName: 'Test Network Rules'
            inputs:
              azureSubscription: 'Azure-Terraform-SP'
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                # Validate firewall rules
                az network firewall policy rule collection list \
                  --resource-group rg-vwan-dev \
                  --firewall-policy afw-dev-policy \
                  --output table

          - script: |
              # Custom validation script
              python tests/validate_deployment.py
            displayName: 'Run Custom Tests'
```

---

## Example 6: Cost Estimation Pipeline

Using Infracost for cost estimates.

```yaml
trigger:
  - main
  - develop

pr:
  - main

pool:
  vmImage: 'ubuntu-latest'

jobs:
  - job: CostEstimation
    displayName: 'Estimate Infrastructure Cost'
    
    steps:
      - script: |
          curl -L https://github.com/infracost/infracost/releases/latest/download/infracost-linux-amd64 -o infracost
          chmod +x infracost
        displayName: 'Install Infracost'

      - script: |
          ./infracost configure set api_key ${{ secrets.INFRACOST_API_KEY }}
        displayName: 'Configure Infracost API Key'
        env:
          INFRACOST_API_KEY: $(INFRACOST_API_KEY)

      - task: TerraformInstaller@0
        displayName: 'Install Terraform'

      - task: TerraformTaskV3@3
        displayName: 'Terraform Init'
        inputs:
          provider: 'azurerm'
          command: 'init'

      - script: |
          ./infracost breakdown --path . --format html > cost-report.html
          ./infracost breakdown --path . --format json > cost-report.json
        displayName: 'Generate Cost Report'

      - task: PublishBuildArtifacts@1
        displayName: 'Publish Cost Report'
        inputs:
          pathToPublish: 'cost-report.html'
          artifactName: 'cost-estimate'

      - script: |
          MONTHLY_COST=$(./infracost breakdown --path . --format json | jq '.summary.totalMonthlyCost')
          echo "Estimated monthly cost: \$${MONTHLY_COST}"
          echo "##vso[task.setvariable variable=estimatedCost]$MONTHLY_COST"
        displayName: 'Extract Cost'

      - task: GitHubCommentPR@0
        displayName: 'Comment Cost on PR'
        inputs:
          githubConnection: 'GitHub'
          comment: |
            ## 💰 Cost Estimation
            
            **Estimated monthly cost**: $$(estimatedCost)
            
            See artifacts for detailed breakdown.
        condition: eq(variables['Build.Reason'], 'PullRequest')
```

---

## Example 7: Notification and Reporting

Send alerts and reports.

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

jobs:
  - job: Deploy
    steps:
      - task: TerraformInstaller@0
      - task: TerraformTaskV3@3
        displayName: 'Terraform Apply'
        inputs:
          provider: 'azurerm'
          command: 'apply'
          commandOptions: '-auto-approve'
          environmentServiceNameAzureRM: 'Azure-Terraform-SP'

      - script: terraform output -json > output.json
        displayName: 'Export Outputs'

      - task: PowerShell@2
        displayName: 'Send Teams Notification'
        inputs:
          targetType: 'inline'
          script: |
            $json = Get-Content output.json | ConvertFrom-Json
            $fwIP = $json.firewall_private_ip.value
            
            $body = @{
              "@type" = "MessageCard"
              "@context" = "https://schema.org/extensions"
              "summary" = "vWAN Deployment Complete"
              "themeColor" = "0078D4"
              "sections" = @(@{
                "activityTitle" = "Azure vWAN Infrastructure Deployed"
                "facts" = @(
                  @{"name"="Status"; "value"="✅ Success"},
                  @{"name"="Firewall IP"; "value"=$fwIP},
                  @{"name"="Timestamp"; "value"=(Get-Date)}
                )
              })
            }
            
            $uri = "$(TEAMS_WEBHOOK_URL)"
            Invoke-RestMethod -uri $uri -Method POST -body (ConvertTo-Json $body) -ContentType 'application/json'

      - task: SendEmail@1
        displayName: 'Send Email Report'
        inputs:
          To: 'devops@company.com'
          Subject: 'vWAN Deployment Report'
          Body: |
            Deployment completed successfully.
            
            Firewall: $(cat output.json | jq -r '.firewall_private_ip.value')
            vWAN: $(cat output.json | jq -r '.vwan_id.value')
```

---

## Quick Reference: Pipeline Components

| Component | Usage | Example |
|-----------|-------|---------|
| **trigger** | Controls what starts pipeline | `branches`, `paths`, `schedule` |
| **pr** | PR validation settings | Branch validation, code review checks |
| **pool** | Build agent | `ubuntu-latest`, `windows-latest` |
| **stages** | Logical workflow phases | Validate, Test, Deploy |
| **jobs** | Units of work | Build, Test, Deploy each run |
| **steps** | Individual actions | Install tool, Run command |
| **tasks** | Pre-built actions | TerraformTaskV3, AzureCLI |
| **conditions** | When to execute | `succeeded()`, `eq(branch)` |
| **variables** | Environment data | Subscription, credentials |
| **artifacts** | Output files | Plans, reports, logs |

---

## Choosing the Right Pattern

| Scenario | Use |
|----------|-----|
| Simple CI/CD | Example 1 (Two-Environment) |
| Multi-region | Example 2 (Multi-Region) |
| Detect drift | Example 3 (Drift Detection) |
| Emergency cleanup | Example 4 (Destroy) |
| Validate deployments | Example 5 (Integration Testing) |
| Track costs | Example 6 (Cost Estimation) |
| Team notification | Example 7 (Notifications) |

---

For more information, see [AZURE-DEVOPS-SETUP.md](../docs/AZURE-DEVOPS-SETUP.md)
