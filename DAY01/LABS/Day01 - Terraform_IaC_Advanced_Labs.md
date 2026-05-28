# Terraform IaC Advanced Labs

## Existing Labs
Refer to the previously created modules covering environment setup, basic configuration, variables, modules, and remote state management.

## Advanced Terraform Labs

### Lab 5: Provisioning Virtual Machines

**Objective:** Deploy a virtual machine in Azure using Terraform.

**Steps:**
1. Reuse the network created in the Hands-On lab by reading the existing resource group, virtual network, and subnet.
2. Create a network interface using `azurerm_network_interface`.
3. Provision a virtual machine using `azurerm_linux_virtual_machine` or `azurerm_windows_virtual_machine`.
4. Specify admin credentials and SSH keys.
5. Run `terraform apply` to deploy the VM.

### Lab 6: Managing Secrets with Azure Key Vault

**Objective:** Securely store and retrieve the VM password using Azure Key Vault.
**Steps:**
1. Augment Code (Add Key Vault)
2. Create and Use the Secret

### Lab 7: Implementing Terraform Workspaces

**Objective:** Use Terraform workspaces to manage multiple environments, such as dev, test, and prod.

**Steps:**
1. Initialize Terraform and create new workspaces using `terraform workspace new <name>`.
2. Switch between workspaces using `terraform workspace select <name>`.
3. Use workspace-specific variables or state files.
4. Deploy resources in isolated environments.
5. Verify workspace isolation with `terraform show` and `terraform state list`.

## Instructor Guide: Advanced Labs Step-by-Step

This document provides a detailed, step-by-step implementation guide for the labs described in Terraform_IaC_Advanced_Labs.docx. The guide below covers Labs 6, 7, and 8 with code examples and explanations.

### Lab 5: Provisioning Virtual Machines

**Objective:** Deploy a complete, functional Azure Virtual Machine (Linux) on top of the existing network created in the Hands-On lab.

#### Step 1: Project Preparation
Create a new empty folder, for example `lab6-vm`. Create the `main.tf`, `variables.tf`, and `outputs.tf` files.

#### Step 2: Define Variables (`variables.tf`)
Define the input variables, including the existing network names from the Hands-On lab and the admin password for the machine, which must be marked as sensitive.

```hcl
variable "location" {
	description = "The Azure region."
	type        = string
	default     = "West Europe"
}

variable "existing_network_resource_group_name" {
	description = "The resource group that contains the Hands-On lab network."
	type        = string
	default     = "lab-foundation-rg"
}

variable "existing_virtual_network_name" {
	description = "The name of the Hands-On lab virtual network."
	type        = string
	default     = "lab-foundation-vnet"
}

variable "existing_subnet_name" {
	description = "The subnet name inside the Hands-On lab virtual network."
	type        = string
	default     = "internal-app-subnet"
}

variable "vm_admin_username" {
	description = "Administrator username for the VM."
	type        = string
	default     = "terraformadmin"
}

variable "vm_admin_password" {
	description = "Administrator password for the VM. (Use SSH keys in production!)"
	type        = string
	sensitive   = true
}
```

#### Step 3: Define Resources (`main.tf`)
Use the existing Hands-On lab network by reading the existing resource group, virtual network, and subnet, then create only the VM-specific resources.

```hcl
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

data "azurerm_resource_group" "network" {
	name = var.existing_network_resource_group_name
}

data "azurerm_virtual_network" "main" {
	name                = var.existing_virtual_network_name
	resource_group_name = data.azurerm_resource_group.network.name
}

data "azurerm_subnet" "main" {
	name                 = var.existing_subnet_name
	virtual_network_name = data.azurerm_virtual_network.main.name
	resource_group_name  = data.azurerm_resource_group.network.name
}

resource "azurerm_resource_group" "main" {
	name     = "vm-lab-rg"
	location = var.location
}

resource "azurerm_network_security_group" "main" {
	name                = "vm-lab-nsg"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name

	security_rule {
		name                       = "AllowSSH"
		priority                   = 1001
		direction                  = "Inbound"
		access                     = "Allow"
		protocol                   = "Tcp"
		source_port_range          = "*"
		destination_port_range     = "22"
		source_address_prefix      = "*"
		destination_address_prefix = "*"
	}
}

resource "azurerm_public_ip" "main" {
	name                = "vm-lab-pip"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name
	allocation_method   = "Static"
	sku                 = "Standard"
}

resource "azurerm_network_interface" "main" {
	name                = "vm-lab-nic"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name

	ip_configuration {
		name                          = "internal"
		subnet_id                     = data.azurerm_subnet.main.id
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id          = azurerm_public_ip.main.id
	}
}

resource "azurerm_network_interface_security_group_association" "main" {
	network_interface_id      = azurerm_network_interface.main.id
	network_security_group_id = azurerm_network_security_group.main.id
}

resource "azurerm_linux_virtual_machine" "main" {
	name                            = "main-vm"
	resource_group_name             = azurerm_resource_group.main.name
	location                        = azurerm_resource_group.main.location
	size                            = "Standard_B1s"
	admin_username                  = var.vm_admin_username
	admin_password                  = var.vm_admin_password
	disable_password_authentication = false

	network_interface_ids = [
		azurerm_network_interface.main.id,
	]

	os_disk {
		caching              = "ReadWrite"
		storage_account_type = "Standard_LRS"
	}

	source_image_reference {
		publisher = "Canonical"
		offer     = "0001-com-ubuntu-server-jammy"
		sku       = "22_04-lts"
		version   = "latest"
	}
}
```

#### Step 4: Define Outputs (`outputs.tf`)
Output the VM's public IP address so you can log in.

```hcl
output "vm_public_ip" {
	description = "The public IP address of the virtual machine."
	value       = azurerm_public_ip.main.ip_address
}
```

#### Step 5: Workflow
1. Authenticate with Azure CLI using `az login`.
2. Initialize Terraform with `terraform init`.
3. Apply the configuration and provide the password on the command line:

```bash
terraform apply -var="vm_admin_password=PA$$w0rd1234!"
```

4. Connect using the IP address from the output:

```bash
ssh terraformadmin@<OUTPUT_IP_ADDRESS>
```

5. Clean up when finished:

```bash
terraform destroy -var="vm_admin_password=PA$$w0rd1234!"
```

### Lab 6: Managing Secrets with Azure Key Vault

**Objective:** Securely store and retrieve the VM password using Azure Key Vault.

#### Step 1: Augment Code (Add Key Vault)
Modify `main.tf` to create a Key Vault.

```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
	name                = "kv-lab-${random_id.main.hex}"
	location            = azurerm_resource_group.main.location
	resource_group_name = azurerm_resource_group.main.name
	tenant_id           = data.azurerm_client_config.current.tenant_id
	sku_name            = "standard"

	access_policy {
		tenant_id = data.azurerm_client_config.current.tenant_id
		object_id = data.azurerm_client_config.current.object_id

		secret_permissions = [
			"Set", "Get", "Delete", "List", "Purge"
		]
	}
}

resource "random_id" "main" {
	byte_length = 4
}
```

#### Step 2: Create and Use the Secret
Instead of passing the password directly into the VM, create a secret and read it back using a data block.

```hcl
resource "azurerm_key_vault_secret" "vm_password" {
	name         = "vm-admin-password"
	value        = var.vm_admin_password
	key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_key_vault_secret" "vm_password_data" {
	name         = azurerm_key_vault_secret.vm_password.name
	key_vault_id = azurerm_key_vault.main.id

	depends_on = [azurerm_key_vault_secret.vm_password]
}

resource "azurerm_linux_virtual_machine" "main" {
	# ... other arguments remain ...
	admin_password = data.azurerm_key_vault_secret.vm_password_data.value
	# ...
}
```

#### Step 3: Workflow
1. Run `terraform init` because of the new `random_id` provider.
2. Apply the configuration:

```bash
terraform apply -var="vm_admin_password=PA$$w0rd1234!"
```

Terraform will create the Key Vault, add the secret, read it back, and use it to create the VM.

Important: even though the value is sensitive, the secret still ends up in state, so the state file must be protected.

### Lab 7: Implementing Terraform Workspaces

**Objective:** Use the same codebase to manage dev and prod environments using separate state files.

#### Step 1: Modify Code (Use the Workspace)
Use `terraform.workspace` to name resources and avoid collisions.

```hcl
locals {
	env_prefix = terraform.workspace == "default" ? "dev" : terraform.workspace
}

resource "azurerm_resource_group" "main" {
	name     = "vm-lab-rg-${local.env_prefix}"
	location = var.location
}

resource "azurerm_virtual_network" "main" {
	name = "vm-lab-vnet-${local.env_prefix}"
	# ... rest of it ...
}

# Append local.env_prefix to the name argument of all other resources.
```

#### Step 2: Workspace Workflow
1. Current state:

```bash
terraform workspace list
```

This will show `* default`.

2. Optional: rename `default` to `dev`.
3. Run dev:

```bash
terraform workspace select dev
terraform apply -var="vm_admin_password=..."
```

Terraform creates the `...-rg-dev` resource group and all other resources.

4. Create prod:

```bash
terraform workspace new prod
terraform apply -var="vm_admin_password=..."
```

Terraform runs the code again in the `prod` workspace and creates the `...-rg-prod` resource group.

5. Check the Azure Portal. You should now see both `...-rg-dev` and `...-rg-prod` resource groups.

6. Switch and clean up:

```bash
terraform workspace select dev
terraform destroy -var="vm_admin_password=..."
terraform workspace select prod
terraform destroy -var="vm_admin_password=..."
```
