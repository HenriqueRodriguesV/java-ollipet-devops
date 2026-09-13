#!/usr/bin/env bash
# Limpeza: remove TODOS os recursos criados (grupo inteiro). Use apos a
# correcao/apresentacao para nao deixar recursos consumindo credito na Azure.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "Isso vai apagar o resource group '${RESOURCE_GROUP}' e TODOS os recursos dentro dele."
read -r -p "Confirma? (digite 'sim'): " CONFIRMACAO
if [ "${CONFIRMACAO}" != "sim" ]; then
    echo "Cancelado."
    exit 0
fi

az group delete --name "${RESOURCE_GROUP}" --yes --no-wait
echo "==> Remocao disparada (--no-wait). Acompanhe com: az group show --name ${RESOURCE_GROUP}"
