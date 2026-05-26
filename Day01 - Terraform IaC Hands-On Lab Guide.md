# Terraform IaC Hands-On Lab Guide

This document combines a compact lab outline with a more detailed instructor guide for Labs 1-5. The examples are formatted as proper Markdown so the preview renders cleanly and the Terraform snippets are readable.

## Quick Lab Outline

### Lab 1: Environment Setup
**Objective:** Prepare your local environment for Terraform development.

1. Install Terraform CLI from https://developer.hashicorp.com/terraform/downloads.
2. Install Azure CLI from https://learn.microsoft.com/en-us/cli/azure/install-azure-cli.
3. Authenticate to Azure using `az login`.
4. Create a Service Principal:

```bash
az ad sp create-for-rbac --name terraform-sp --role Contributor --scopes /subscriptions/<your-subscription-id>
```

5. Save credentials securely for use in Terraform.

## Lab 2: Declare the Network Foundation
**Objective:** Build the foundational Azure network infrastructure upon which the application will be deployed in the following days.

### Steps:
1. Create a new directory for your project and open it in VS Code.
2. Create a `versions.tf` file to configure the provider:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}
```

3. Create a `main.tf` file. This will contain the foundational Resource Group, the Virtual Network (VNet), and the Subnet.

```hcl
provider "azurerm" {
  features {}
}

# 1. Foundational Resource Group
resource "azurerm_resource_group" "network_rg" {
  name     = "lab-foundation-rg"
  location = "West Europe"
}

# 2. Core Virtual Network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "lab-foundation-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

# 3. Application Subnet
resource "azurerm_subnet" "app_subnet" {
  name                 = "internal-app-subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

4. Initialize the project:

```bash
terraform init
```

5. Preview and apply the configuration:

```bash
terraform plan

terraform apply
```

### Lab 3: Use Variables and Outputs
**Objective:** Parameterize your configuration and expose key outputs.

1. Create `variables.tf`.

```hcl
variable "location" {
  type        = string
  default     = "West Europe"
}

variable "prefix" {
  type        = string
  default     = "lab-foundation"
}
```

2. Update `main.tf` to use the variable:

```hcl


provider "azurerm" {
  features {}
}

  name     = "${var.prefix}-rg"
  location = var.location

  name                = "${var.prefix}-vnet"
 

```

3. Create `outputs.tf`.

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}
```

4. Re-run `terraform apply` and observe the output.

### Lab 4: State Management and Remote Backend
**Objective:** Configure remote state storage using Azure Storage.

1. Create a storage account and container in Azure.
2. Add backend configuration to `main.tf`.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateaccount"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}
```

3. Reinitialize Terraform using `terraform init`.

## Instructor Guide: Basic Labs Step-by-Step (Lab 1-4)

This document provides a detailed, step-by-step implementation guide for the foundational labs (Lab 1-4) described in Terraform_IaC_HandsOn_Lab_Guide.docx. The labs are designed to build upon each other.

### Lab 1: Environment Setup

**Objective:** Prepare your local environment for Terraform development.

#### Step 1: Install Terraform CLI
* Open in your browser: https://developer.hashicorp.com/terraform/downloads
* Download the appropriate package for your OS (e.g., Windows 64-bit).
* Unzip the terraform.exe file into a folder (e.g., `C:\Terraform`).
* Add this folder to your System Path environment variable so it can be accessed from any command prompt.
* **Verification:** Open a new terminal and type `terraform --version`. If successful, it will print the version number.

#### Step 2: Install Azure CLI
* Open in your browser: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
* Install using the Windows Installer.
* **Verification:** Open a new terminal and type `az --version`.

#### Step 3: Authenticate to Azure
* In your terminal, run the following command: `az login`
* This will open a browser window. Log in to the Microsoft account associated with your Azure subscription.
* After a successful login, the terminal will list your subscriptions.

#### Step 4: Create a Service Principal
* In production, we don't use our personal user to run Terraform, but a technical user (Service Principal).
* Find your Subscription ID using `az account show`.
* Run the following command, replacing `<your-subscription-id>` with your own:

```bash
az ad sp create-for-rbac --name terraform-sp --role Contributor --scopes /subscriptions/<your-subscription-id>
```

* Save the resulting JSON object (appId, password, tenant) in a secure location. We will use this in CI/CD pipelines and the provider block if not using `az login`.

### Lab 2: Declare the Network Foundation

**Objective:** Build the foundational Azure network infrastructure (Resource Group, Virtual Network, Subnet) used by later labs.

#### Step 1: Create project directory and files
- Create a folder for the lab (for example `terraform-labs/day1-network`) and open it in VS Code.
- Create `versions.tf`, `main.tf` and optionally `variables.tf`/`outputs.tf`.

#### Step 2: Add provider version constraints (`versions.tf`)
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}
```

#### Step 3: Write the network resources (`main.tf`)
Copy the following into `main.tf`. It defines the provider, a Resource Group, a Virtual Network and a Subnet.

```hcl
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "network_rg" {
  name     = "lab-foundation-rg"
  location = var.location == "" ? "West Europe" : var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "lab-foundation-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "internal-app-subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

If you want to use a variable for location, add a `variables.tf` with:

```hcl
variable "location" {
  type    = string
  default = "West Europe"
}
```

#### Step 4: Initialize and apply
Run the standard Terraform workflow in the lab folder:

```bash
terraform init
terraform plan
terraform apply
```

#### Verification
- Confirm in the Azure Portal or with `az` that the resource group `lab-foundation-rg`, the `lab-foundation-vnet` and the `internal-app-subnet` exist.

#### Notes
- Choose globally-unique names for shared resources if you will reuse these labs in parallel environments.
- Keep `terraform.tfstate` secure; in later labs we configure a remote backend.

### Lab 3: Use Variables and Outputs

**Objective:** Parameterize the configuration by extracting hard-coded values into variables.

#### Step 1: Create `variables.tf`
* Create a new file named `variables.tf`.

```hcl
# variables.tf

variable "location" {
  type        = string
  description = "resource location"
  default     = "West Europe"
}

variable "prefix" {
  type        = string
  description = "All resource names will begin with this prefix."
  default     = "lab-foundation"
}
```

#### Step 2: Create `outputs.tf`
* Create a new file named `outputs.tf`.

```hcl
# outputs.tf

output "subnet_id" {
  value       = azurerm_subnet.app_subnet.id
  description = "The unique identifier of the created subnet."
}
```

#### Step 3: Modify `main.tf`
* Modify your `main.tf` file to reference the variables instead of hard-coded strings.

```hcl
# main.tf (UPDATED)

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "network_rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "internal-app-subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

#### Step 4: Run and Override Values
* Run `terraform apply` again.
* Terraform will notice that the default variable is different from what's in the state file. Approve the change with `yes`.
* Override the values using `-var`:

```bash
terraform apply -var="prefix=Lab-hands-on" -var="location=North Europe"
```

* Terraform will now use these values instead of the default ones.

### Lab 4: State Management and Remote Backend

#### Step 1: Create Azure Storage Account (Manually)
* This is a chicken-and-egg problem. We need state storage to exist before Terraform can use it.
* Go to the Azure Portal.
* Create a new Resource Group (e.g., `tfstate-rg`).
* Create a new Storage Account (e.g., `tfstatelab12345`). The name must be globally unique.
* Inside the Storage Account, create a new Container (e.g., `tfstate`).

#### Step 2: Add Backend Configuration to `main.tf`
* Open your root `main.tf` file.
* Add the `backend "azurerm" { ... }` block inside the `terraform { ... }` block.

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstatelab12345"
    container_name       = "tfstate"
    key                  = "day1-lab.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
resource "azurerm_resource_group" "network_rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "internal-app-subnet"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

#### Step 3: Re-initialize and Migrate
* Because we added the backend block, we must re-initialize.

```bash
terraform init
```

* Terraform will detect that you have a local `terraform.tfstate` file and have configured a remote backend.
* It will ask whether it should copy the existing state to the new backend.
* Type `yes` and press Enter.
* Terraform will upload your local state file to the Azure Storage Account.
* **Verification:** Delete your local `terraform.tfstate` and `terraform.tfstate.backup` files.
* Run `terraform plan`. Terraform will now download the state from Azure and should report `No changes`, indicating the sync was successful.

