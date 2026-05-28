Quick setup guide to create prerequisites for the CI/CD lab.

Steps overview:

1) Create Azure resources (run the PowerShell script):

```powershell
# From repository root or the ci-cd-lab/scripts folder
pwsh ./scripts/create_azure_prereqs.ps1
```

This will:
- create a resource group
- create a storage account and a container
- create a service principal scoped to the resource group
- write `prereqs_output.json` with credentials (keep secret)

2) Create an Azure DevOps repo and Service Connection:
- Use the Azure DevOps portal to create a repo or use `az devops` CLI (see `create_ado_instructions.md`).
- Create a Service Connection in Project Settings > Service connections. Use the service principal credentials from `prereqs_output.json` if you choose manual creation.

3) Create a Variable Group in Azure DevOps called `TF-SECRETS` and set the backend variables:
- `ARM_BACKEND_RG` : resource group name
- `ARM_BACKEND_SA` : storage account name
- `ARM_BACKEND_CONTAINER` : container name
- `ARM_BACKEND_KEY` : storage account key (mark secret)

4) Push the lab contents and create the pipeline:
- Add the `ci-cd-lab` folder contents to your repo, commit and push.
- In Azure DevOps, create a pipeline pointing to `azure-pipelines.yml` in the repo.

Security reminder:
- Do not commit credentials or `prereqs_output.json` to source control.

If you want, I can:
- create a git commit locally with these files (I cannot push without your credentials), or
- guide you interactively through running the PowerShell script and creating the service connection in the portal.
