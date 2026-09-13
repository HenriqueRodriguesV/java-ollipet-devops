#!/usr/bin/env bash
# Passo 5: smoke test do CRUD fim a fim contra o ambiente publicado no ACI.
# Use este script durante a gravacao para evidenciar a integracao entre App e
# Banco em nuvem (o SELECT de conferencia continua sendo feito no proprio
# Postgres, ex.: az container exec ... -- psql, mostrado ao vivo no video).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./00-variaveis.sh

BASE_URL="http://${DNS_LABEL}.${LOCATION}.azurecontainer.io:8080"
echo "==> Base URL: ${BASE_URL}"

echo "==> Login"
TOKEN=$(curl -s -X POST "${BASE_URL}/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"maria.silva@email.com","senha":"123456"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")
echo "Token obtido."

echo "==> CREATE pet"
curl -s -X POST "${BASE_URL}/api/v1/pets" \
    -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
    -d '{"nome":"Amora","descricao":"Cadastrada via smoke test do deploy","raca":"SRD","especie":"CAO","dataNascimento":"2023-05-20"}'
echo

echo "==> LISTAR pets do tutor"
curl -s "${BASE_URL}/api/v1/pets/meus" -H "Authorization: Bearer ${TOKEN}"
echo

echo ""
echo "Para conferir no banco (dentro do container 'db' do mesmo grupo):"
echo "  az container exec --resource-group ${RESOURCE_GROUP} --name ${CONTAINER_GROUP} --container-name db --exec-command \"psql -U ${DB_USER:-ollipet} -d ${DB_NAME:-ollipet} -c 'SELECT * FROM pet;'\""
