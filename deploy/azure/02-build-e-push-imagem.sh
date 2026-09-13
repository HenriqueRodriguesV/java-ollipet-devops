#!/usr/bin/env bash
# Passo 2: build da imagem da aplicacao DENTRO do Azure (ACR Tasks) e push
# automatico para o registry - nao precisa de docker login/push manual.
# Equivalente a: docker build -t <acr>.azurecr.io/ollipet-api:v1 . && docker push ...
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

echo "==> Build remoto no ACR (contexto: raiz do repositorio)"
az acr build \
    --registry "${ACR_NAME}" \
    --image "${APP_IMAGE}:${APP_IMAGE_TAG}" \
    ../..

echo "==> Imagem publicada:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${APP_IMAGE}" -o table
