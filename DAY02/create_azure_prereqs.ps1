<#
PowerShell script to create Azure prerequisites for the lab.
Requires: Azure CLI (az) logged in (az login) and permission to create resource groups, storage accounts and service principals.
Run: powershell -ExecutionPolicy Bypass -File .\create_azure_prereqs.ps1
#>
param(
  [string]$subscriptionId = "",
  [string]$resourceGroup = "tf-lab-backend-rg",
  [string]$location = "westeurope",
  [string]$storageAccountName = "tflabbackendsa$(Get-Random -Maximum 9999)",
  [string]$containerName = "tfstate",
  [string]$spName = "http://tf-lab-sp"
)

if(-not $subscriptionId){
  $subscriptionId = (az account show --query id -o tsv) 2>$null
}

Write-Host "Using subscription: $subscriptionId"

Write-Host "Creating resource group $resourceGroup in $location..."
az group create --name $resourceGroup --location $location | Out-Null

Write-Host "Creating storage account $storageAccountName (Standard_LRS)..."
az storage account create --name $storageAccountName --resource-group $resourceGroup --location $location --sku Standard_LRS --kind StorageV2 | Out-Null

Write-Host "Creating storage container $containerName..."
$accountKey = az storage account keys list -g $resourceGroup -n $storageAccountName --query [0].value -o tsv
az storage container create --name $containerName --account-name $storageAccountName --account-key $accountKey | Out-Null

Write-Host "Creating service principal $spName with Contributor role scoped to resource group..."
$spJson = az ad sp create-for-rbac --name $spName --role Contributor --scopes /subscriptions/$subscriptionId/resourceGroups/$resourceGroup --sdk-auth -o json
if($LASTEXITCODE -ne 0){
  Write-Error "Failed to create service principal. Check your permissions and run 'az login' and retry."
  exit 1
}

Write-Host "Service principal created. Saving credentials to prereqs_output.json (do NOT commit this file to source control)."
$creds = @{ 
  subscriptionId = $subscriptionId;
  resourceGroup = $resourceGroup;
  location = $location;
  storageAccountName = $storageAccountName;
  containerName = $containerName;
  servicePrincipal = ($spJson | ConvertFrom-Json)
}
$creds | ConvertTo-Json -Depth 5 | Out-File -FilePath "prereqs_output.json" -Encoding utf8

Write-Host "Done. Next steps:"
Write-Host "  - Note the storage account name: $storageAccountName"
Write-Host "  - Use the created service principal JSON for creating an Azure DevOps Service Connection (manual or via az devops CLI)."
Write-Host "  - Create a variable group in Azure DevOps named 'TF-SECRETS' and populate backend values (ARM_BACKEND_RG, ARM_BACKEND_SA, ARM_BACKEND_CONTAINER, ARM_BACKEND_KEY)."

Write-Host "prereqs_output.json contains the service principal credentials and resource names. Keep it secret."
