#!/usr/bin/env bash
# Espelha a imagem oficial postgres:16-alpine para o nosso ACR.
#
# Motivo: em alguns momentos o Azure Container Instances recebe
# "RegistryErrorResponse ... index.docker.io" ao puxar imagens publicas
# direto do Docker Hub (rate limit/instabilidade de pulls anonimos). Ter
# nossa propria copia no ACR remove essa dependencia externa no deploy.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

ACR_LOGIN_SERVER=$(az acr show --name "${ACR_NAME}" --query loginServer -o tsv)

# O ACI so roda imagens amd64. "docker pull --platform linux/amd64" nem
# sempre troca a tag local se a imagem ja estiver em cache com outra
# arquitetura (observado em Mac Apple Silicon com Docker Desktop) - por isso
# resolvemos o digest amd64 explicitamente no manifest list e puxamos por
# digest, que e confiavel.
AMD64_DIGEST=$(docker buildx imagetools inspect postgres:16-alpine --format '{{json .Manifest}}' \
    | python3 -c "import sys,json; m=json.load(sys.stdin); print(next(x['digest'] for x in m['manifests'] if x.get('platform',{}).get('architecture')=='amd64' and x.get('platform',{}).get('os')=='linux'))")
echo "==> Digest amd64 de postgres:16-alpine -> ${AMD64_DIGEST}"

echo "==> docker pull postgres@${AMD64_DIGEST}"
docker pull "postgres@${AMD64_DIGEST}"

echo "==> docker tag + push para ${ACR_LOGIN_SERVER}/postgres:16-alpine"
docker tag "postgres@${AMD64_DIGEST}" "${ACR_LOGIN_SERVER}/postgres:16-alpine"

ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" -o tsv)
echo "${ACR_PASSWORD}" | docker login "${ACR_LOGIN_SERVER}" -u "${ACR_NAME}" --password-stdin
docker push "${ACR_LOGIN_SERVER}/postgres:16-alpine"
