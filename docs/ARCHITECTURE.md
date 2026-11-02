# Architecture

## Goals

- A private AKS cluster with no public API endpoint
- Every Azure resource defined in Terraform, every change through a pull request
- Workloads delivered by GitOps, so CI never needs network access to the cluster
- No long-lived credentials: OIDC for CI, workload identity for pods
- Cheap enough to run as a lab: up for a session, destroyed afterward

## Components

| Layer | Component | Purpose |
|---|---|---|
| Delivery | GitHub Actions | Plan on PR, apply on merge; build, scan and push images |
| Delivery | Flux (AKS GitOps extension) | Pulls `gitops/` from GitHub and reconciles the cluster |
| Identity | Entra app registrations (plan, apply) | OIDC-federated CI identities with least privilege |
| Identity | Workload identity | Pods exchange a service account token for an Entra token |
| Network | Hub VNet | Jump VM running Tailscale as a subnet router; room for a firewall |
| Network | Spoke VNet | AKS node subnet and private endpoint subnet |
| Network | Private DNS zones | Resolve private endpoints for Key Vault and the AKS API from both VNets |
| Compute | Private AKS | Free tier, one system node, Azure CNI Overlay with Cilium |
| Data | Key Vault (RBAC mode) | App secret, reached over a private endpoint |
| Data | ACR (Basic) | Container images; kubelet identity has AcrPull |
| Observability | kube-prometheus-stack | Prometheus, Grafana, Alertmanager |
| Observability | Container Insights + Azure Monitor | Node health alert by email |
| State | Storage account (bootstrap) | Terraform state, Entra ID auth only |

## Trust boundaries

```
 PR from branch ──► plan identity   (Reader, read-only state)
 merge to main  ──► apply identity  (Contributor + constrained RBAC admin)
 laptop         ──► Tailscale ──► hub jump VM ──► private AKS API
 Flux (in cluster) ──► github.com (outbound only)
 app pod ──► workload identity ──► Key Vault private endpoint
```

## Request path: merge to running pod

Filled in during Phase 3.
