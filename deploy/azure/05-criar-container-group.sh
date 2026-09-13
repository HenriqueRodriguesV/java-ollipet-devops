#!/usr/bin/env bash
# Passo 4: sobe o container group (App + Banco) no ACI a partir do template
# YAML, com os segredos injetados via variavel de ambiente (nunca commitados).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

if [ -f .storage-key.local ]; then
    # shellcheck disable=SC1091
    source .storage-key.local
fi

: "${DB_PASSWORD:?defina em deploy/azure/.env.azure}"
: "${APP_SECURITY_JWT_SECRET:?defina em deploy/azure/.env.azure}"
: "${STORAGE_KEY:?rode 03-criar-storage.sh antes}"

export ACR_LOGIN_SERVER
ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)
export ACR_USERNAME="${ACR_NAME}"
export ACR_PASSWORD
ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" -o tsv)
export DB_NAME="${DB_NAME:-ollipet}"
export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}"

echo "==> Gerando manifesto a partir do template"
envsubst < container-group.template.yaml > container-group.generated.yaml

echo "==> Criando container group ${CONTAINER_GROUP} (App + Banco)"
az container create \
    --resource-group "${RESOURCE_GROUP}" \
    --file container-group.generated.yaml

echo "==> Aguardando IP publico..."
az container show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CONTAINER_GROUP}" \
    --query "{status:instanceView.state, fqdn:ipAddress.fqdn, ip:ipAddress.ip}" \
    -o table

echo "==> API disponivel em: http://${DNS_LABEL}.${LOCATION}.azurecontainer.io:8080/swagger-ui.html"
