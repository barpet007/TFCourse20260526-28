Azure DevOps setup instructions (requires Azure DevOps organization and optionally az devops CLI extension).

Prerequisites:
- Install Azure CLI and sign in: `az login`
- (Optional) Install Azure DevOps extension: `az extension add --name azure-devops`
- Acquire an Azure DevOps Personal Access Token (PAT) with sufficient permissions to create repos and service connections.

1) Create a Git repo in Azure DevOps (portal) or via CLI:

Using az devops (set defaults first):

```bash
az devops configure --defaults organization=https://dev.azure.com/<ORG> project=<PROJECT>
az repos create --name TFCourseLabs
```

2) Create an Azure DevOps Service Connection (Azure Resource Manager)

Manual (Portal):
- Go to Project settings > Service connections > New service connection > Azure Resource Manager > Service principal (automatic)
- Fill in the details or choose service principal (manual) and paste the JSON from `prereqs_output.json` created by the PowerShell script (use the "servicePrincipal" object for credentials).
- Give it a name such as `TF-SERVICE-CONNECTION` and grant access to all pipelines if needed.

Using az devops CLI (advanced, requires PAT configured and az devops extension):

- Prepare a JSON payload with the service principal credentials; example fields required include subscriptionId, subscriptionName, tenantId, clientId, clientSecret. The exact schema depends on the CLI command.

3) Create a Variable Group `TF-SECRETS` in the Library (Portal) or via CLI

Portal: Pipelines > Library > + Variable group > Name: TF-SECRETS
- Add variables:
  - `ARM_BACKEND_RG` = resource group name
  - `ARM_BACKEND_SA` = storage account name
  - `ARM_BACKEND_CONTAINER` = container name
  - `ARM_BACKEND_KEY` = storage account key (mark as secret)
- Save and authorize for pipelines.

Using az pipelines CLI:

```bash
az pipelines variable-group create --name TF-SECRETS --variables ARM_BACKEND_RG=<rg> ARM_BACKEND_SA=<sa> ARM_BACKEND_CONTAINER=<container>
# For secrets, you'll need to set via REST API or portal to mark as secret
```

4) Push code to the created repo and configure the pipeline
- Clone the repo locally and add the `ci-cd-lab` folder contents.
- Commit and push: `git add .` `git commit -m "Add CI/CD lab files"` `git push origin main`
- In Azure DevOps: Pipelines > New pipeline > Use the repo and select `azure-pipelines.yml`.

Notes & Tips:
- Creating the Service Connection via CLI often requires organization-level permissions and a PAT. If you prefer, create it via the portal using the service principal credentials produced by the PowerShell script.
- Never commit `prereqs_output.json` or any client secrets to source control.
