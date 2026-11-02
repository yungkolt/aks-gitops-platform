# Runbook

How to bring the platform up, tear it down, and debug it.

## Prerequisites

- Azure CLI 2.60+, Terraform 1.9+, GitHub CLI (`gh`), logged in to the right account
- An Azure subscription where you are **Owner** (bootstrap creates role assignments)
- Permission to create app registrations in Entra ID (the default for most tenants)
- This repository on GitHub

```bash
az login
az account set --subscription <subscription-id>
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
gh auth login
```

## Phase 0: bootstrap (once per subscription)

### 1. Register resource providers

```bash
./infra/bootstrap/register-providers.sh
```

### 2. Apply the bootstrap stack

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id and your email
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

This creates, in order of importance:

1. A monthly **$25 budget** with alerts at 50% actual, 100% actual and 100% forecast
2. The **state storage account** (Entra ID auth only, versioning and soft delete on)
3. The **plan** and **apply** app registrations with GitHub federated credentials and their role assignments
4. `infra/envs/dev/backend.hcl` with the real storage account name

Back up `infra/bootstrap/terraform.tfstate` somewhere safe (a password manager attachment works). It is gitignored.

### 3. Configure GitHub

```bash
cd ../..                                     # repo root
terraform -chdir=infra/bootstrap output -raw github_variables_commands | bash
gh api -X PUT repos/{owner}/{repo}/environments/dev \
  -F "deployment_branch_policy[protected_branches]=false" \
  -F "deployment_branch_policy[custom_branch_policies]=true"
gh api -X POST repos/{owner}/{repo}/environments/dev/deployment-branch-policies \
  -f name=main -f type=branch
```

These are repository **variables**, not secrets. Nothing secret is stored in GitHub.

Then, in **Settings → Branches**, protect `main`: require a pull request and require the `fmt, validate, checkov` and `plan` checks to pass.

### 4. Commit the generated backend config

```bash
git checkout -b chore/backend-config
git add infra/envs/dev/backend.hcl
git commit -m "chore(infra): point dev backend at bootstrap state account"
git push -u origin chore/backend-config
gh pr create --fill
```

**Done when:** the PR shows a `Terraform plan: dev succeeded` comment planning one resource group. Merge it and the `apply` job creates the group.

## Every session

```bash
# Bring up: merge to main, or locally:
cd infra/envs/dev
terraform init -backend-config=backend.hcl
terraform apply -var-file=dev.tfvars

# Tear down at the end of the session:
terraform destroy -var-file=dev.tfvars
```

The budget, state and identities live in bootstrap and are not affected by `destroy`.

## Debugging

| Symptom | Likely cause | Fix |
|---|---|---|
| `AADSTS70021: No matching federated identity record` | Subject mismatch: workflow ran outside a PR or outside the `dev` environment, or repo was renamed | Check `github_owner`/`github_repo` in bootstrap and the job's `environment:` |
| `AuthorizationPermissionMismatch` on `terraform init` | Missing Storage Blob Data role, or role assignment still propagating | Wait 2–5 minutes after bootstrap; check role assignments on the state account |
| `Key based authentication is not permitted` | Backend not using Entra ID | Ensure `use_azuread_auth = true` in `backend.hcl` and `ARM_USE_AZUREAD=true` |
| `MissingSubscriptionRegistration` | Provider not registered | Rerun `register-providers.sh` |
| Apply fails creating a role assignment | Role not in `assignable_roles` | Add it to the bootstrap variable and re-apply bootstrap |
| No plan comment on a PR from a fork | Forks do not receive OIDC tokens | Expected; push the branch to this repo instead |
