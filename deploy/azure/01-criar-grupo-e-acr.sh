#!/usr/bin/env bash
# Passo 1: grupo de recursos + Azure Container Registry.
# Requisito da entrega: todos os recursos criados via Azure CLI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "==> Criando resource group ${RESOURCE_GROUP} em ${LOCATION}"
az group create --name "${RESOURCE_GROUP}" --location "${LOCATION}"

echo "==> Criando Azure Container Registry ${ACR_NAME}"
az acr create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --location "${LOCATION}" \
    --public-network-enabled true \
    --admin-enabled true

echo "==> ACR criado:"
az acr list --resource-group "${RESOURCE_GROUP}" -o table
