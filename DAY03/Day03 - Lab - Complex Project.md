# Day 03 Lab - Branch-Based DEV / PRD Terraform Deployment

## Objective
Build a Terraform + Azure DevOps lab that uses two branches and two deployment targets:

- `develop` branch deploys automatically to DEV under `RG-DEV-LAB03`
- `main` branch deploys to PRD under `rg-PRD-LAB03`
- DEV is automatic after push
- PRD requires approval for both CI and CD execution flow in Azure DevOps
- Checkov blocks insecure storage settings until the code is fixed

This version is designed to live under Day 03 and replaces the older single-environment lab flow.

## What is already prepared
The previous lab already has these Azure DevOps items, so do not recreate them:

- Service Connection
- `TF-SECRETS` variable group

## ADO repo setup

In Azure DevOps, create a new Git repository named `TFCourseDAY03LAB`.

Create the branch structure like this:

- `main` is the base branch
- `develop` is created from `main`

## What goes on each branch

- `develop` branch:
  - DEV-specific Terraform code
  - `dev.tfvars`
  - settings that deploy into `RG-DEV-LAB03`
  - push here should trigger the DEV deployment automatically

- `main` branch:
  - PRD-specific Terraform code
  - `prod.tfvars`
  - settings that deploy into `rg-PRD-LAB03`
  - PRD should wait for approval before CD continues

If you want to confirm what already exists, check the previous lab notes or Azure DevOps project settings.

## Branch model

- `develop` -> DEV deployment
- `main` -> PRD deployment
- Optional manual override through pipeline parameters:
  - `auto`
  - `dev`
  - `prod`
  - `plan`
  - `apply`
  - `destroy`

## Expected environments

- DEV resources go into `RG-DEV-LAB03`
- PRD resources go into `rg-PRD-LAB03`

## Intentional Checkov failures
The initial DEV configuration is supposed to fail Checkov on two controls:

- Storage account TLS version is too weak: `TLS1_0`
- Storage account replication uses `LRS` instead of `GRS`

After fixing those values, CI should pass and CD should continue.

## Suggested project structure

```text
/
├── modules/
│   └── simple_storage/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── dev.tfvars
├── prod.tfvars
├── azure-pipelines.yml
├── checkov/
│   └── custom_policies/
└── scripts/
    └── bootstrap_prereqs.ps1
```

## Terraform root module

`main.tf`

```terraform
terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  common_tags = {
    lab       = "LAB03"
    managedBy = "terraform"
  }
}

resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    environment = var.environment
  })
}

module "storage" {
  source = "./modules/simple_storage"

  resource_group_name      = azurerm_resource_group.lab.name
  location                 = azurerm_resource_group.lab.location
  storage_account_name     = var.storage_account_name
  account_replication_type = var.storage_account_replication_type
  min_tls_version          = var.storage_account_min_tls_version
  tags                     = merge(local.common_tags, { environment = var.environment })
}

output "resource_group_name" {
  value = azurerm_resource_group.lab.name
}

output "storage_account_name" {
  value = module.storage.storage_account_name
}

output "storage_account_id" {
  value = module.storage.storage_account_id
}
```

`versions.tf`

```terraform
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
```

`variables.tf`

```terraform
variable "environment" {
  description = "Deployment environment name (dev or prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], lower(var.environment))
    error_message = "environment must be dev or prod."
  }
}

variable "location" {
  description = "Azure region for the lab resources."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name of the target resource group."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account to deploy."
  type        = string

  validation {
    condition     = length(var.storage_account_name) >= 3 && length(var.storage_account_name) <= 24
    error_message = "storage_account_name must be between 3 and 24 characters."
  }
}

variable "storage_account_replication_type" {
  description = "Storage replication type (LRS for dev lab failure, GRS for production)."
  type        = string

  validation {
    condition     = contains(["LRS", "GRS"], upper(var.storage_account_replication_type))
    error_message = "storage_account_replication_type must be LRS or GRS."
  }
}

variable "storage_account_min_tls_version" {
  description = "Minimum TLS version for the storage account."
  type        = string

  validation {
    condition     = contains(["TLS1_0", "TLS1_1", "TLS1_2"], upper(var.storage_account_min_tls_version))
    error_message = "storage_account_min_tls_version must be TLS1_0, TLS1_1, or TLS1_2."
  }
}

variable "common_tags" {
  description = "Optional extra tags applied to all resources."
  type        = map(string)
  default     = {}
}
```

## Storage module

`modules/simple_storage/main.tf`

```terraform
resource "azurerm_storage_account" "sa" {
  name                     = lower(replace(var.storage_account_name, "-", ""))
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  min_tls_version          = var.min_tls_version

  tags = var.tags
}
```

`modules/simple_storage/variables.tf`

```terraform
variable "resource_group_name" {
  description = "Name of the resource group that hosts the storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "storage_account_name" {
  description = "Name of the storage account to create."
  type        = string
}

variable "account_replication_type" {
  description = "Replication type for the storage account (LRS or GRS)."
  type        = string
}

variable "min_tls_version" {
  description = "Minimum TLS version for the storage account."
  type        = string
}

variable "tags" {
  description = "Optional tags to apply to the storage account."
  type        = map(string)
  default     = {}
}
```

`modules/simple_storage/outputs.tf`

```terraform
output "storage_account_id" {
  description = "ID of the created storage account."
  value       = azurerm_storage_account.sa.id
}

output "storage_account_name" {
  description = "Name of the created storage account."
  value       = azurerm_storage_account.sa.name
}
```

## Environment tfvars

`dev.tfvars`

```hcl
environment                      = "dev"
location                         = "westeurope"
resource_group_name              = "RG-DEV-LAB03"
storage_account_name             = "stdevlab03"
storage_account_replication_type = "LRS"
storage_account_min_tls_version  = "TLS1_0"
```

`prod.tfvars`

```hcl
environment                      = "prod"
location                         = "westeurope"
resource_group_name              = "rg-PRD-LAB03"
storage_account_name             = "stprdlab03"
storage_account_replication_type = "GRS"
storage_account_min_tls_version  = "TLS1_2"
```

## Azure DevOps pipeline

The pipeline should:

- trigger on `develop` and `main`
- resolve the environment automatically from the branch, or let the user override it with a parameter
- run Terraform init in CI and again in CD
- run Checkov before plan
- publish the plan as a pipeline artifact in CI
- download the artifact in CD
- support `plan`, `apply`, and `destroy`

### Pipeline sketch

```yaml
trigger:
  branches:
    include:
      - develop
      - main

parameters:
  - name: environmentMode
    type: string
    default: auto
    values:
      - auto
      - dev
      - prod

  - name: terraformAction
    type: string
    default: apply
    values:
      - plan
      - apply
      - destroy

stages:
  - stage: CI
    displayName: CI - Validate, Scan, Plan
    jobs:
      - job: Plan
        steps:
          - checkout: self
          - task: TerraformInstaller@1
          - script: pip install checkov
          - task: TerraformTaskV4@4
            displayName: Terraform Init
          - script: checkov --directory . --framework terraform --external-checks-dir ./checkov/custom_policies
          - task: TerraformTaskV4@4
            displayName: Terraform Plan
          - task: PublishPipelineArtifact@1
            displayName: Publish Terraform Plan

  - stage: CD
    displayName: CD - Apply or Destroy
    dependsOn: CI
    jobs:
      - deployment: DeployDev
        displayName: DEV deployment
        condition: or(eq('${{ parameters.environmentMode }}', 'dev'), and(eq('${{ parameters.environmentMode }}', 'auto'), ne(variables['Build.SourceBranchName'], 'main')))
        environment: 'DEV-LAB03'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: DownloadPipelineArtifact@2
                - task: TerraformInstaller@1
                - task: TerraformTaskV4@4
                  displayName: Terraform Init
                - task: TerraformTaskV4@4
                  displayName: Terraform Apply
                - task: TerraformTaskV4@4
                  displayName: Terraform Destroy

      - deployment: DeployProd
        displayName: PRD deployment
        condition: or(eq('${{ parameters.environmentMode }}', 'prod'), and(eq('${{ parameters.environmentMode }}', 'auto'), eq(variables['Build.SourceBranchName'], 'main')))
        environment: 'PRD-LAB03'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: DownloadPipelineArtifact@2
                - task: TerraformInstaller@1
                - task: TerraformTaskV4@4
                  displayName: Terraform Init
                - task: TerraformTaskV4@4
                  displayName: Terraform Apply
                - task: TerraformTaskV4@4
                  displayName: Terraform Destroy
```

## Checkov policies

Add custom policies so the lab intentionally fails until the code is fixed:

- TLS must be `TLS1_2`
- replication must be `GRS`

Example files:

`checkov/custom_policies/storage_tls.yaml`

```yaml
metadata:
  name: Azure Storage accounts must use TLS 1.2
  id: CKV_CUSTOM_STORAGE_TLS_1
  category: ENCRYPTION
definition:
  cond_type: attribute
  resource_types:
    - azurerm_storage_account
  attribute: min_tls_version
  operator: equals
  value: TLS1_2
```

`checkov/custom_policies/storage_replication.yaml`

```yaml
metadata:
  name: Azure Storage accounts must use GRS replication
  id: CKV_CUSTOM_STORAGE_REPL_1
  category: BACKUP AND RECOVERY
definition:
  cond_type: attribute
  resource_types:
    - azurerm_storage_account
  attribute: account_replication_type
  operator: equals
  value: GRS
```

## Prerequisites script

The script should only create the backend storage resources. The Service Connection and `TF-SECRETS` variable group already exist from the previous lab.

`scripts/bootstrap_prereqs.ps1`

```powershell
param(
  [string]$Location = "westeurope",
  [string]$BackendResourceGroupName = "rg-lab03-backend",
  [string]$BackendStorageAccountName = "",
  [string]$BackendContainerName = "tfstate"
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
  throw "Azure CLI is not installed. Install az before running this script."
}

$azLogin = az account show --query id -o tsv 2>$null
if (-not $azLogin) {
  Write-Host "You are not signed in to Azure CLI. Run 'az login' first."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($BackendStorageAccountName)) {
  $randomSuffix = Get-Random -Minimum 1000 -Maximum 9999
  $BackendStorageAccountName = "stlab03$randomSuffix"
}

az group create --name $BackendResourceGroupName --location $Location | Out-Null
az storage account create --name $BackendStorageAccountName --resource-group $BackendResourceGroupName --location $Location --sku Standard_LRS --kind StorageV2 | Out-Null
az storage container create --name $BackendContainerName --account-name $BackendStorageAccountName | Out-Null

$storageKey = az storage account keys list --resource-group $BackendResourceGroupName --account-name $BackendStorageAccountName --query "[0].value" -o tsv

$summary = [ordered]@{
  backendResourceGroup = $BackendResourceGroupName
  backendStorageAccount = $BackendStorageAccountName
  backendContainer      = $BackendContainerName
  backendKey            = $storageKey
  serviceConnection     = "Already prepared from the previous lab"
  variableGroup         = "Already prepared from the previous lab"
}

$summary | ConvertTo-Json -Depth 3 | Out-File -FilePath (Join-Path $PSScriptRoot 'prereqs_output.json') -Encoding utf8
```

## Lab flow

1. Create or switch to the `develop` branch.
2. Push the first version of the code.
3. Observe CI failing on Checkov because of `TLS1_0` and `LRS`.
4. Fix the storage settings in `dev.tfvars` or the root/module inputs.
5. Push again and verify DEV deploys automatically.
6. Merge or push to `main` and verify PRD requires approval.
7. Use the pipeline parameters for `plan`, `apply`, or `destroy` as needed.

## Notes

- DEV and PRD use separate resource group names.
- CI must publish the Terraform plan artifact.
- CD must run `terraform init` again before `apply` or `destroy`.
- The PRD environment should be protected by Azure DevOps approvals.

## What to keep from the previous lab

Keep these as-is:

- Azure DevOps Service Connection
- `TF-SECRETS` variable group

Those do not need to be recreated.
