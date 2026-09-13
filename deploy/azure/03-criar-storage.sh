#!/usr/bin/env bash
# Passo 3: Storage Account + Azure File Share, usados como volume persistente
# do container do Postgres (sem isso, os dados do banco somem a cada restart
# do container no ACI, que roda em disco efemero).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "==> Criando storage account ${STORAGE_ACCOUNT}"
az storage account create \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${STORAGE_ACCOUNT}" \
    --location "${LOCATION}" \
    --sku Standard_LRS

echo "==> Obtendo chave de acesso"
STORAGE_KEY=$(az storage account keys list \
    --resource-group "${RESOURCE_GROUP}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --query "[0].value" -o tsv)

echo "==> Criando file share ${FILESHARE_NAME}"
az storage share create \
    --name "${FILESHARE_NAME}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_KEY}" \
    --quota 5

echo "STORAGE_KEY=${STORAGE_KEY}" > .storage-key.local
echo "==> Chave salva em deploy/azure/.storage-key.local (nao versionado)"
