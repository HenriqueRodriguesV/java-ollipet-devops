#!/usr/bin/env bash
# Variaveis compartilhadas pelos scripts de deploy (ACR + ACI).
# Convencao de nomes seguindo a usada em aula: <turma><RM> do integrante que
# criou os recursos.
#
# Uso: source 00-variaveis.sh (nao execute diretamente)

export RM="rm562917"
export TURMA="2tdsa"
# eastus2 nao esta liberada nesta subscription (Azure for Students) por
# politica de regiao; eastus foi a regiao que a Azure aceitou.
export LOCATION="eastus"

export RESOURCE_GROUP="rg-${RM}-devops"
export ACR_NAME="${TURMA}${RM}"                 # nome do Azure Container Registry (globalmente unico)
export APP_IMAGE="ollipet-api"
export APP_IMAGE_TAG="v1"

export STORAGE_ACCOUNT="st${RM}ollipet"         # so letras minusculas e numeros, <=24 chars
export FILESHARE_NAME="pgdata"

export CONTAINER_GROUP="ollipet-aci"
export DNS_LABEL="ollipet-${RM}"                # vira http://ollipet-rm562917.eastus2.azurecontainer.io:8080

# Segredos: NUNCA commitar valores reais. Copie deploy/azure/.env.azure.example
# para deploy/azure/.env.azure (ja esta no .gitignore) e ajuste antes de rodar
# os scripts 03+.
if [ -f "$(dirname "${BASH_SOURCE[0]}")/.env.azure" ]; then
    # shellcheck disable=SC1091
    source "$(dirname "${BASH_SOURCE[0]}")/.env.azure"
fi
