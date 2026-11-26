# aks-gitops-platform

A private Azure Kubernetes Service platform built entirely with Terraform inside a hub-spoke network. A small Python API is delivered to the cluster through GitOps with Flux, reads its secret from Key Vault using workload identity, and is monitored with Prometheus and Grafana. Every infrastructure change ships through a pull request: GitHub Actions posts a Terraform plan on the PR and applies it on merge, authenticating to Azure with OIDC so no credentials are stored in GitHub.

> Status: **Phase 0 (bootstrap)** complete. See [Roadmap](#roadmap).

## Architecture

```
GitHub ──────────────────────────────────────────────────────────────────┐
  Actions: plan on PR, apply on merge, build/scan/push image (OIDC)      │
  Repo: infra/, app/, gitops/ (desired state)  ◄── Flux pulls (outbound) │
                                                                          │
Azure subscription (Terraform) ──────────────────────────────────────────┤
  Hub VNet:   jump VM + Tailscale subnet router  ◄── laptop (kubectl)    │
     │ peering                                                            │
  Spoke VNet: private AKS (no public API)                                │
                ├─ app (FastAPI, Helm)                                    │
                ├─ Prometheus / Grafana                                   │
                └─ Flux                                                   │
              private endpoint ── Key Vault (RBAC mode)                   │
  Shared: Terraform state storage · ACR · Log Analytics                  │
└─────────────────────────────────────────────────────────────────────────┘
```

Nothing calls into the private cluster. Flux runs inside it and pulls desired state from this repo, so CI never needs network access to the Kubernetes API. Full detail in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Key decisions

Each tradeoff is written up in [docs/DECISIONS.md](docs/DECISIONS.md). Highlights so far:

- Separate plan and apply identities, federated to GitHub with OIDC (no client secrets)
- Terraform state in Entra ID–authenticated storage with shared keys disabled
- Budget and state live in a bootstrap stack so `terraform destroy` on the lab never removes them

## Repo layout

```
infra/
  bootstrap/      one-time: budget, state storage, GitHub OIDC identities
  modules/        network, aks, acr, keyvault, monitoring
  envs/dev/       root module wiring the modules together
app/              FastAPI service, Dockerfile, tests
charts/app/       Helm chart for the service
gitops/           Flux Kustomizations, HelmReleases and values
.github/workflows terraform.yml (infra), app.yml (image)
docs/             ARCHITECTURE, DECISIONS, RUNBOOK, screenshots
```

## Bringing it up

Start with [docs/RUNBOOK.md](docs/RUNBOOK.md). Short version:

1. Apply `infra/bootstrap` once from your machine.
2. Set the GitHub repository variables it prints.
3. Open a PR that touches `infra/`; the plan appears as a PR comment. Merge to apply.

This is run as a lab: bring it up for a session, then `terraform destroy`. State and the budget survive in the bootstrap stack.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| 0 | Budget, remote state, OIDC identities, PR plan workflow | Done |
| 1 | Hub-spoke network, NSGs, private DNS, Tailscale jump VM | Planned |
| 2 | Private AKS, Azure CNI Overlay + Cilium, Entra RBAC, ACR, Key Vault, Flux | Planned |
| 3 | FastAPI app, image pipeline with Trivy, Helm chart, GitOps delivery | Planned |
| 4 | kube-prometheus-stack, dashboards, alerts, postmortem | Planned |
| 5 | Network policy, Azure Policy, hardening, demo | Planned |
| 6 | Hybrid: Arc-connected homelab cluster on the same GitOps tree | Planned |
