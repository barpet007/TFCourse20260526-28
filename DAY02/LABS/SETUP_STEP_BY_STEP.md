# Terraform CI/CD Lab Setup Guide

Ez a fájl a lab előkészítését írja le külön, strukturált formában. A parancsok külön ki vannak emelve, a fontos változók pedig vastagon szerepelnek.

## 1. Cél

A cél egy olyan Azure DevOps CI/CD pipeline előkészítése, amely:

1. létrehozza a Terraform remote backendet,
2. használ egy Azure DevOps Service Connectiont,
3. egy `TF-SECRETS` nevű Variable Group-ból veszi át a titkokat,
4. és csak akkor folytatja a deploy-t, ha a Checkov scan sikeres.

## 2. Szükséges előfeltételek

- Azure CLI telepítve
- Azure DevOps projekt létrehozva
- Írási jog az Azure subscriptionben
- Jogosultság Service Connection és Variable Group létrehozásához Azure DevOps-ban

## 3. Azure oldali előkészítés

### 3.1 Azure CLI bejelentkezés

Futtasd ezeket a parancsokat:

```powershell
az --version
az login
az account set --subscription <SUBSCRIPTION ID>
```

### 3.2 Prerequisites script futtatása

A script létrehozza a backendhez szükséges erőforrásokat és elmenti az eredményt a `prereqs_output.json` fájlba.

```powershell
cd "d:\DEVOPS\TF Course\TF_Course\Day 02\Labs\ci-cd-lab\scripts"
powershell -NoProfile -ExecutionPolicy Bypass -File .\create_azure_prereqs.ps1
```

### 3.3 Fontos változók a scriptből

A script által létrehozott fő értékek:

- **resourceGroup**: `tf-lab-backend-rg`
- **storageAccountName**: `tflabbackendsa6091` vagy egy új, véletlenszerű név
- **containerName**: `tfstate`
- **subscriptionId**: az aktuális Azure subscription azonosítója
- **location**: `westeurope`

### 3.4 Storage account key lekérése

A backendhez szükséges kulcsot így tudod lekérni:

```powershell
az storage account keys list -g tf-lab-backend-rg -n tflabbackendsa6091 --query "[0].value" -o tsv
```

Ha más storage account nevet kaptál, a `-n` értékét cseréld ki arra.

## 4. Azure DevOps előkészítés

### 4.1 Repository létrehozása

Az Azure DevOps-ban hozz létre egy új Git repository-t a projektedhez.

Ha CLI-ből akarod:

```bash
az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>
az repos create --name TFCourseLabs
```

A helykitöltők:

- **<ORG>**: az Azure DevOps szervezeted neve
- **<PROJECT>**: a projekt neve

### 4.2 Service Connection létrehozása

Az Azure DevOps-ban menj ide:

1. Project settings
2. Service connections
3. New service connection
4. Azure Resource Manager
5. Service principal (manual)

A szükséges értékek a `prereqs_output.json` fájlban vannak a `servicePrincipal` objektumban.

Fontos mezők:

- **clientId**
- **clientSecret**
- **tenantId**
- **subscriptionId**

A Service Connection neve legyen:

- **TF-SERVICE-CONNECTION**

### 4.3 TF-SECRETS Variable Group létrehozása

Az Azure DevOps-ban menj ide:

1. Pipelines
2. Library
3. + Variable group
4. Név: **TF-SECRETS**

Vedd fel ezeket a változókat:

- **ARM_BACKEND_RG** = a backend resource group neve
- **ARM_BACKEND_SA** = a backend storage account neve
- **ARM_BACKEND_CONTAINER** = a backend container neve
- **ARM_BACKEND_KEY** = a storage account kulcs, secretként

A `TF_VAR_` előtaggal ellátott változók automatikusan betöltődhetnek a Terraformba.

## 5. Repo tartalom és fájlstruktúra

A lab fájlstruktúra:

```text
modules/
└── simple_storage/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
main.tf
versions.tf
azure-pipelines.yml
```

## 6. Pipeline futtatása lépésről lépésre

### 6.1 Fájlok feltöltése

A helyi repo-ból commitold és pushold a lab fájlokat.

```bash
git add .
git commit -m "Add CI/CD lab files"
git push origin main
```

### 6.2 Pipeline létrehozása Azure DevOps-ban

1. Pipelines
2. New pipeline
3. Azure Repos Git
4. Válaszd a repo-t
5. Existing Azure Pipelines YAML file
6. `azure-pipelines.yml`
7. Save and run

### 6.3 Mit kell látnod első futáskor

A Checkov scan a lab célja szerint először hibát találhat, ha a module-ban van szándékos eltérés.

A Checkov parancs a pipeline-ban:

```bash
checkov --directory . --framework terraform --check CKV_AZURE_54
```

Ha a szabály rendben van, a pipeline továbbmegy a Terraform Plan felé.

## 7. Hibakeresés

### 7.1 Ha a `pwsh` nem ismert

Windows alatt használd ezt:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\create_azure_prereqs.ps1
```

### 7.2 Ha a Checkov túl sok hibát ad

A lab demóhoz célszerű a csak a szükséges szabályt futtatni:

```bash
checkov --directory . --framework terraform --check CKV_AZURE_54
```

## 8. Rövid összefoglaló

Használt fő parancsok:

```powershell
az login
az account set --subscription d6971119-76ac-45b7-a27c-7e15dfc13c8d
powershell -NoProfile -ExecutionPolicy Bypass -File .\create_azure_prereqs.ps1
az storage account keys list -g tf-lab-backend-rg -n tflabbackendsa6091 --query "[0].value" -o tsv
```

Kulcs változók:

- **TF-SERVICE-CONNECTION**
- **TF-SECRETS**
- **ARM_BACKEND_RG**
- **ARM_BACKEND_SA**
- **ARM_BACKEND_CONTAINER**
- **ARM_BACKEND_KEY**

## 9. Biztonsági megjegyzés

A `prereqs_output.json` tartalmazhat érzékeny adatot, például Service Principal `clientSecret` értéket. Ezt ne commitáld a repóba.
