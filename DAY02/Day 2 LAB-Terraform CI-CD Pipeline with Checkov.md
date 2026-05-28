________________________________________
🧪 Hands-on Lab: Terraform CI/CD Pipeline Implementation
Objective: To deploy a simple Azure infrastructure (Resource Group and Storage Account) using a reusable Terraform module via an Azure DevOps CI/CD pipeline, ensuring the deployment only proceeds after a successful Checkov security scan.
1. Prerequisites (Setup)
Item	Details
Azure Setup	Ensure you have an existing Azure Storage Account configured to host the Remote State file (backend).
Azure DevOps	A configured Service Connection that grants necessary Azure permissions to your pipeline (required for the Terraform Apply step).
Git Repository	An empty Git repo (Azure DevOps or GitHub) to store your Terraform code.
________________________________________
1: Using Terraform with CI/CD Pipelines
Objective: Integrate Terraform into a CI/CD pipeline using Azure DevOps.
Steps:
1.	Create a Terraform configuration repository in Azure Repos.
2.	Define a pipeline YAML file to run terraform init, plan, and apply.
3.	Use environment variables or secrets to store credentials.
4.	Configure pipeline triggers on pull requests or commits.
5.	Validate infrastructure changes through automated plans.
2: Managing Secrets with Azure Key Vault
Objective: Store and retrieve secrets securely using Azure Key Vault in Terraform.
Steps:
6.	Create an azurerm_key_vault resource.
7.	Add secrets using azurerm_key_vault_secret.
8.	Reference secrets in other resources using data sources.
9.	Ensure access policies are configured for Terraform's Service Principal.
10.	Use terraform output to expose secret references (not values).
3. Prepare the Terraform Code and Modules
Participants must create the following file structure within their Git repository:
├── modules/
│   └── simple_storage/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── versions.tf
└── azure-pipelines.yml
A. Create the Module (with an Intentional Flaw)
The module will create a Resource Group and Storage Account. To demonstrate Checkov's role, intentionally include a configuration that fails a standard security check (e.g., setting the minimum TLS version too low or enabling public access).
•	modules/simple_storage/main.tf (Ensure a policy violation exists here):
Terraform
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = lower(replace(var.storage_account_name, "-", ""))
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  # Policy Flaw: Missing the 'min_tls_version' setting or public access enabled (Checkov violation)
}
B. Root Configuration (main.tf)
The root configuration calls the module and sets the remote backend.
•	main.tf:
Terraform
terraform {
  required_providers { /* ... */ }
  backend "azurerm" { 
    # Configure remote backend parameters here using secrets/variables
  }
}
# Call the module
module "storage_deploy" {
  source                 = "./modules/simple_storage"
  resource_group_name    = "tf-rg-$(Build.BuildId)"
  storage_account_name   = "tfsa$(Build.BuildId)"
  location               = var.location
}
________________________________________
4. Build the CI/CD Pipeline (Azure DevOps YAML)
The azure-pipelines.yml file defines two main stages: CI (Scan/Plan) and CD (Apply).
YAML
# azure-pipelines.yml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: TF-SECRETS # Ensure Service Connection and Backend keys are linked
  location: 'westeurope'

stages:
- stage: CI_SCAN_PLAN
  displayName: 'Checkov Scan and Plan'
  jobs:
  - job: Plan
    steps:
    - task: TerraformInstaller@1 # 1. Install Terraform
      displayName: 'Install Terraform'

    - script: |
        pip install checkov # 2. Install Checkov
      displayName: 'Install Checkov'

    - task: TerraformTaskV4@4 # 3. Terraform Init
      displayName: 'Terraform Init'
      inputs:
        provider: 'azurerm'
        command: 'init'
        backendType: 'azurerm'
        backendServiceArm: 'TF-SERVICE-CONNECTION' # Your Service Connection name
        # ... other backend parameters

    - script: |
        checkov --directory . --framework terraform --skip-check CKV_AZURE_114 # 4. Run Checkov
      displayName: 'Checkov Security Scan'
      # IMPORTANT: This step is expected to FAIL initially due to the intentional flaw!

    - task: TerraformTaskV4@4 # 5. Terraform Plan (Only runs if Checkov is successful)
      displayName: 'Terraform Plan'
      inputs:
        provider: 'azurerm'
        command: 'plan'
        environmentServiceNameAzureRM: 'TF-SERVICE-CONNECTION'
        # Save plan output for the next stage
        
- stage: CD_APPLY
  displayName: 'Deployment'
  # Must have an explicit approval gate configured in the Environment settings
  dependsOn: CI_SCAN_PLAN
  condition: succeeded('CI_SCAN_PLAN')
  jobs:
  - job: Apply
    steps:
    - task: TerraformTaskV4@4
      displayName: 'Terraform Apply'
      inputs:
        provider: 'azurerm'
        command: 'apply'
        environmentServiceNameAzureRM: 'TF-SERVICE-CONNECTION'
        # Use the plan file generated in the previous stage
________________________________________
. Lab Execution Steps (Participant Tasks)
1.	First Run: Execute the pipeline with the original, intentionally flawed module code.
o	Expected Result: The Checkov Security Scan step will FAIL, immediately stopping the pipeline before Terraform Plan runs.
2.	Fix the Flaw: Participants must analyze the Checkov error message, locate the security flaw in the modules/simple_storage/main.tf, and fix it (e.g., adding min_tls_version = "TLS1_2"). Commit and push the corrected code.
3.	Second Run: Re-run the pipeline with the fixed code.
o	Expected Result: The Checkov Security Scan succeeds, Terraform Plan runs, and the CD_APPLY stage successfully deploys the infrastructure.
4.	Verification and Cleanup: Verify the created resources in the Azure Portal. Run a final pipeline execution (or a dedicated destroy job) to clean up the resources.
This exercise ensures participants understand the full flow: coding $\rightarrow$ policy check $\rightarrow$ planning $\rightarrow$ approval $\rightarrow$ deployment.

 
Instructor Guide: Checkov CI/CD Lab Step-by-Step

________________________________________
🧪 Hands-on Lab: Terraform CI/CD Pipeline Implementation

## Objective

Deploy a simple Azure infrastructure (Resource Group and Storage Account) using a reusable Terraform module via an Azure DevOps CI/CD pipeline, ensuring the deployment only proceeds after a successful Checkov security scan.

---

## 1 — Prerequisites (Setup)

- Azure Setup: An existing Azure Storage Account to host the remote state (backend).
- Azure DevOps: A configured Service Connection that grants necessary Azure permissions to the pipeline (required for Terraform Apply).
- Git Repository: An empty Git repository (Azure DevOps or GitHub) to store Terraform code.

---

## 2 — Using Terraform with CI/CD Pipelines

Objective: Integrate Terraform into a CI/CD pipeline using Azure DevOps.

Steps:

1. Create a Terraform configuration repository in Azure Repos.
2. Define an Azure Pipelines YAML to run `terraform init`, `plan`, and `apply`.
3. Use environment variables or secrets to store credentials.
4. Configure pipeline triggers on pull requests or commits.
5. Validate infrastructure changes through automated plans.

---

## 3 — Managing Secrets with Azure Key Vault

Objective: Store and retrieve secrets securely using Azure Key Vault in Terraform.

Steps:

1. Create an `azurerm_key_vault` resource.
2. Add secrets using `azurerm_key_vault_secret`.
3. Reference secrets in other resources using data sources.
4. Ensure access policies are configured for Terraform's Service Principal.
5. Use `terraform output` to expose secret references (not values).

---

## 4 — Prepare the Terraform Code and Modules

Required repository structure:

```
modules/
└── simple_storage/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
main.tf
versions.tf
azure-pipelines.yml
```

### A. Create the Module (with an intentional flaw)

The module creates a Resource Group and a Storage Account. To demonstrate Checkov's role, include a configuration that fails a standard security check (e.g., missing `min_tls_version`).

`modules/simple_storage/main.tf` (example):

```terraform
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "sa" {
  name                     = lower(replace(var.storage_account_name, "-", ""))
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  # INTENTIONAL FLAW: missing `min_tls_version` — Checkov will flag this (CKV_AZURE_54)
  # min_tls_version = "TLS1_2"
}
```

`modules/simple_storage/variables.tf` (example):

```terraform
variable "resource_group_name" {
  description = "Name of the Resource Group."
  type        = string
}

variable "location" {
  description = "The Azure region."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Storage Account."
  type        = string
}
```

`modules/simple_storage/outputs.tf` (example):

```terraform
output "storage_account_id" {
  description = "The ID of the created Storage Account."
  value       = azurerm_storage_account.sa.id
}
```

### B. Root Configuration (main.tf)

Root `main.tf` calls the module and configures the remote backend. Example minimal files below.

`versions.tf`:

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
```

`main.tf` (root, with backend placeholders):

```terraform
terraform {
  backend "azurerm" {
    resource_group_name  = var.backend_rg
    storage_account_name = var.backend_sa
    container_name       = var.backend_container
    key                  = "day2-lab02.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

module "storage_deploy" {
  source = "./modules/simple_storage"

  resource_group_name  = "tf-rg-${var.build_id}"
  storage_account_name = "tfsa${var.build_id}"
  location             = var.location
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "build_id" {
  type    = string
  default = "local"
}

# Backend variables (injected by pipeline variable group)
variable "backend_rg" { type = string }
variable "backend_sa" { type = string }
variable "backend_container" { type = string }
```

---

## 5 — Build the CI/CD Pipeline (Azure DevOps YAML)

This pipeline defines two main stages: `CI_SCAN_PLAN` (Checkov scan + plan) and `CD_APPLY` (apply with approvals).

`azure-pipelines.yml` (example):

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: TF-SECRETS # Variable group with backend keys
  - name: location
    value: 'westeurope'

stages:
  - stage: CI_SCAN_PLAN
    displayName: 'Checkov Scan and Plan'
    jobs:
      - job: ScanAndPlan
        steps:
          - task: TerraformInstaller@1
            displayName: 'Install Terraform'

          - script: |
              pip install --upgrade pip
              pip install checkov
            displayName: 'Install Checkov'

          - task: TerraformTaskV4@4
            displayName: 'Terraform Init'
            inputs:
              provider: 'azurerm'
              command: 'init'
              backendType: 'azurerm'
              backendServiceArm: 'TF-SERVICE-CONNECTION'
              backendAzureRmResourceGroupName: $(ARM_BACKEND_RG)
              backendAzureRmStorageAccountName: $(ARM_BACKEND_SA)
              backendAzureRmContainerName: $(ARM_BACKEND_CONTAINER)
              backendAzureRmKey: 'day2-lab.terraform.tfstate'

          - script: |
              checkov --directory . --framework terraform --check CKV_AZURE_54
            displayName: 'Checkov Security Scan'

          - task: TerraformTaskV4@4
            displayName: 'Terraform Plan'
            inputs:
              provider: 'azurerm'
              command: 'plan'
              environmentServiceNameAzureRM: 'TF-SERVICE-CONNECTION'
              commandOptions: '-out=tfplan -var="backend_rg=$(ARM_BACKEND_RG)" -var="backend_sa=$(ARM_BACKEND_SA)" -var="backend_container=$(ARM_BACKEND_CONTAINER)"'

          - task: PublishPipelineArtifact@1
            displayName: 'Publish Terraform Plan'
            inputs:
              targetPath: '$(System.DefaultWorkingDirectory)/tfplan'
              artifact: 'terraform_plan'
              publishLocation: 'pipeline'
              
  - stage: CD_APPLY
    displayName: 'Deployment (Apply)'
    dependsOn: CI_SCAN_PLAN
    condition: succeeded('CI_SCAN_PLAN')
    jobs:
      - deployment: Apply
        displayName: 'Terraform Apply'
        environment: 'production' # configure Approvals in ADO Environments
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self  
                
                - task: DownloadPipelineArtifact@2
                  displayName: 'Download Terraform Plan'
                  inputs:
                    buildType: 'current'
                    artifactName: 'terraform_plan'
                    targetPath: '$(System.DefaultWorkingDirectory)'

                - task: TerraformInstaller@1
                  displayName: 'Install Terraform'

                - task: TerraformTaskV4@4
                  displayName: 'Terraform Init'
                  inputs:
                    provider: 'azurerm'
                    command: 'init'
                    backendType: 'azurerm'
                    backendServiceArm: 'TF-SERVICE-CONNECTION'
                    backendAzureRmResourceGroupName: $(ARM_BACKEND_RG)
                    backendAzureRmStorageAccountName: $(ARM_BACKEND_SA)
                    backendAzureRmContainerName: $(ARM_BACKEND_CONTAINER)
                    backendAzureRmKey: 'day2-lab.terraform.tfstate'
                
                - task: TerraformTaskV4@4
                  displayName: 'Terraform Apply'
                  inputs:
                    provider: 'azurerm'
                    command: 'apply'
                    environmentServiceNameAzureRM: 'TF-SERVICE-CONNECTION'
                    commandOptions: 'tfplan'



## Notes:

- The `TF-SECRETS` variable group should contain `ARM_BACKEND_RG`, `ARM_BACKEND_SA`, `ARM_BACKEND_CONTAINER`, and the backend key/secret values.
- The first run is expected to fail at the `Checkov Security Scan` step due to the intentional flaw.

---

## 6 — Lab Execution Steps (Participant Tasks)

1. First run: Commit & push the original (intentionally flawed) module. The pipeline should fail at the Checkov scan.
2. Fix the flaw: Add `min_tls_version = "TLS1_2"` to the storage account resource in `modules/simple_storage/main.tf`, commit and push.
3. Re-run: The Checkov scan should pass, `terraform plan` will run, and after approval the `apply` stage will deploy resources.
4. Cleanup: Add a destroy stage or manually remove the resource group in the Azure Portal.

---

## Validation / Code checks applied

- I reviewed and normalized all code blocks and YAML examples. The Terraform examples use valid HCL structure and include placeholder variables that must be provided by the pipeline or variable group.
- Recommendations before running the pipeline:
  - Ensure `TF-SERVICE-CONNECTION` exists in your Azure DevOps project.
  - Populate the `TF-SECRETS` variable group with backend details and any `TF_VAR_...` values required.
  - Install `checkov` in the pipeline (example included).
