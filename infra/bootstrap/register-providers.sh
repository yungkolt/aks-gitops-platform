#!/usr/bin/env bash
# Registers every resource provider the platform uses. Idempotent; run once
# per subscription before the first bootstrap apply.
set -euo pipefail

providers=(
  Microsoft.Compute
  Microsoft.Consumption
  Microsoft.ContainerRegistry
  Microsoft.ContainerService
  Microsoft.Insights
  Microsoft.KeyVault
  Microsoft.KubernetesConfiguration
  Microsoft.ManagedIdentity
  Microsoft.Network
  Microsoft.OperationalInsights
  Microsoft.OperationsManagement
  Microsoft.PolicyInsights
  Microsoft.Storage
)

for ns in "${providers[@]}"; do
  state=$(az provider show --namespace "$ns" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
  if [[ "$state" == "Registered" ]]; then
    echo "ok        $ns"
  else
    echo "register  $ns"
    az provider register --namespace "$ns" --wait --output none
  fi
done

