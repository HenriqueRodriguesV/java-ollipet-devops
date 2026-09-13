# Roteiro do vídeo — DevOps Tools & Cloud Computing, Sprint 3

Ambiente já validado e no ar. Este roteiro segue exatamente a ordem exigida no
enunciado (avaliação até 80 pontos pelo vídeo). Grave em 720p+, com áudio
claro, sem cortes durante a demonstração do CRUD.

## Dados do ambiente (já criado)

- Resource Group: `rg-rm562917-devops` (região `eastus`)
- ACR: `2tdsarm562917`
- Container group: `ollipet-aci` (containers `app` + `db`)
- API pública: http://ollipet-rm562917.eastus.azurecontainer.io:8080/swagger-ui.html
- Repositório: https://github.com/HenriqueRodriguesV/java-ollipet-devops

## 1. Mostrar os recursos sendo criados na Azure

Se quiser mostrar a criação "ao vivo", primeiro rode (fora da gravação, ou no início dela):
```bash
./deploy/azure/99-remover-recursos.sh   # apaga tudo
```
Depois, **na gravação**, rode em sequência, explicando cada um em voz alta:
```bash
./deploy/azure/01-criar-grupo-e-acr.sh        # Resource Group + ACR
./deploy/azure/02-build-e-push-imagem.sh      # build local + push da imagem do app
./deploy/azure/02b-espelhar-postgres.sh       # espelha o postgres:16-alpine no ACR
./deploy/azure/04-criar-container-group.sh    # sobe App + Banco no ACI
```
Mostre também o Portal Azure (portal.azure.com) com o Resource Group aberto,
os dois recursos (ACR e ACI) e o container group com os 2 containers rodando.

## 2. Clone do repositório (obrigatório começar assim os testes)

```bash
git clone https://github.com/HenriqueRodriguesV/java-ollipet-devops.git
cd java-ollipet-devops
```

## 3. Deploy seguindo o README

Abra o `README.md` na tela e siga a seção **"Deploy na Azure (ACR + ACI)"**
passo a passo (os mesmos comandos do item 1 acima).

## 4. Mostrar o app funcionando na nuvem

- Abra no navegador: http://ollipet-rm562917.eastus.azurecontainer.io:8080/swagger-ui.html
- Aponte que a URL do servidor no Swagger é o FQDN da Azure (não localhost).

## 5. CRUD completo pela API + SELECT no banco

Use o script de smoke test como roteiro (rode os comandos um a um, comentando):
```bash
./deploy/azure/05-testar.sh
```
Para o SELECT direto no banco (evidência exigida no item 9.3), abra um shell
interativo dentro do container do Postgres — **rode isto direto no seu
terminal**, não em modo não-interativo (evita bug de aspas do Azure CLI):
```bash
az container exec --resource-group rg-rm562917-devops --name ollipet-aci --container-name db --exec-command "/bin/sh"
```
Dentro do shell que abrir:
```sh
psql -U ollipet -d ollipet
```
Dentro do `psql`, demonstre cada operação isoladamente:
```sql
-- 1) Estado inicial (Thor, Nina, Bud)
SELECT id_pet, nome, raca, id_resp FROM pet ORDER BY id_pet;

-- 2) INSERT (faça pela API - Swagger ou curl - e depois mostre aqui)
SELECT * FROM pet WHERE nome = 'Amora';

-- 3) UPDATE (faça pela API e mostre aqui)
SELECT * FROM pet WHERE id_pet = <id-da-amora>;

-- 4) DELETE (faça pela API e mostre aqui - deve vir 0 linhas)
SELECT * FROM pet WHERE id_pet = <id-da-amora>;

-- 5) Consulta final
SELECT p.nome AS pet, r.id_usuario AS responsavel_id, u.nome AS tutor
FROM pet p
JOIN responsavel r ON r.id_usuario = p.id_resp
JOIN usuario u ON u.id_usuario = r.id_usuario;
```
Isso evidencia CRUD completo em **duas tabelas relacionadas** (`pet` e
`responsavel`) com prova de persistência real no Postgres em nuvem.

## 6. Fechar

Explique brevemente: opção escolhida (ACR + ACI, containerização completa),
banco não é H2, usuário não-root no container do app, credenciais via
variável de ambiente (nada hardcoded no código).
