# Decisions

One entry per tradeoff. Each records the context, what was chosen, and what was given up. Newest at the bottom.

---

## ADR-001: Terraform for Azure, Flux for the cluster

**Context.** The cluster's API server is private. A CI runner on the internet cannot reach it, so anything that needs `kubectl apply` from CI would require a self-hosted runner inside the VNet or opening the API.

**Decision.** Terraform owns every Azure resource, including the AKS cluster and the Flux extension (both managed through the ARM API, which is public). Flux runs inside the cluster and pulls desired state from `gitops/`. Terraform never manages Kubernetes objects.

**Tradeoffs.** Two tools and two reconciliation loops. In exchange, nothing needs inbound access to the cluster, and the two tools never fight over the same resource.

---

## ADR-002: A separate bootstrap stack with local state

**Context.** Terraform state needs a storage account, and the storage account has to exist before any stack can use it. The budget also needs to exist before anything that costs money.

**Decision.** `infra/bootstrap` creates the state account, the budget and the GitHub identities, using local state. It is applied once by hand. Everything else lives in `infra/envs/dev` with remote state.

**Why the budget lives here and not in `modules/monitoring`.** The lab is destroyed at the end of every session. A budget inside the dev stack would be destroyed with it, which defeats the point.

**Tradeoffs.** Bootstrap state is a local file. It changes rarely and can be rebuilt with `terraform import`, but it should be backed up (see RUNBOOK). Moving it into the state account after the first apply is an option once the account exists.

---

## ADR-003: Entra ID–only access to state

**Decision.** The state storage account has shared keys and SAS disabled (`shared_access_key_enabled = false`). The backend uses `use_azuread_auth = true`, and access is granted with data-plane RBAC roles.

**Why.** An account key is a static, all-powerful secret. With Entra ID auth, every read and write is tied to an identity, auditable, and revocable per principal. Blob versioning and soft delete protect against a bad write.

**Tradeoffs.** The account still has a public endpoint, because GitHub-hosted runners reach it from the internet. A production setup would put state behind a private endpoint and use self-hosted runners in the hub. Checkov is not run against `infra/bootstrap` for this reason.

---

## ADR-004: Separate plan and apply identities over OIDC

**Context.** Pull requests run untrusted changes to workflow files and Terraform code. If PRs could authenticate as the identity that applies, any PR could change infrastructure.

**Decision.** Two Entra app registrations, each with a single federated credential:

| Identity | Federated subject | Azure roles |
|---|---|---|
| plan | `repo:<owner>/<repo>:pull_request` | Reader (subscription), Storage Blob Data Reader (state) |
| apply | `repo:<owner>/<repo>:environment:dev` | Contributor, Storage Blob Data Contributor (state), Role Based Access Control Administrator **constrained to a role list** |

The `dev` GitHub environment is restricted to the `main` branch, so only merged code can mint an apply token. No client secrets exist anywhere.

**Why a constrained RBAC admin instead of Owner or User Access Administrator.** The platform needs Terraform to create role assignments (AcrPull for the kubelet, Key Vault Secrets User for the workload, and so on). An ABAC condition on the role assignment limits the apply identity to creating or deleting assignments for the roles in `var.assignable_roles` only. It cannot grant Owner, Contributor or User Access Administrator, even to itself.

**Tradeoffs.** The plan identity has read-only state access, so plans run with `-lock=false`. A plan could read state mid-apply, which at worst produces a stale plan comment. Applies are serialized by a GitHub concurrency group and still take a state lease.

---

## ADR-005: Resource providers registered outside Terraform

**Decision.** `register-providers.sh` registers every resource provider once per subscription. Both stacks set `resource_provider_registrations = "none"`.

**Why.** The azurerm provider's automatic registration needs write access at subscription scope, which the Reader-only plan identity does not have. `azurerm_resource_provider_registration` fails on providers that are already registered, which most are on an existing subscription, so a script that checks first is simpler.
