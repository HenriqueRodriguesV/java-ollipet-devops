#!/usr/bin/env bash
# Passo 2: build local da imagem da aplicacao e push para o ACR.
#
# Observacao: "az acr build" (build remoto/ACR Tasks) NAO esta disponivel em
# subscriptions "Azure for Students" (retorna TasksOperationsNotAllowed).
# Por isso o build roda localmente com Docker e o push usa as credenciais de
# admin do proprio ACR - o mesmo fluxo docker build / docker login / docker
# push apresentado em aula.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)

echo "==> docker login ${ACR_LOGIN_SERVER}"
ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" -o tsv)
echo "${ACR_PASSWORD}" | docker login "${ACR_LOGIN_SERVER}" -u "${ACR_NAME}" --password-stdin

# --platform linux/amd64 e obrigatorio: o ACI so roda imagens amd64, e um
# build simples em Mac Apple Silicon geraria uma imagem arm64 (rejeitada com
# "ImageOsTypeNotMatchContainerGroup" na criacao do container group).
echo "==> docker buildx build --platform linux/amd64 -t ${ACR_LOGIN_SERVER}/${APP_IMAGE}:${APP_IMAGE_TAG} --push ."
docker buildx build --platform linux/amd64 -t "${ACR_LOGIN_SERVER}/${APP_IMAGE}:${APP_IMAGE_TAG}" --push ../..

echo "==> Imagem publicada:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${APP_IMAGE}" -o table
