-- =============================================================================
-- script_bd.sql - Olli Pet (Challenge Clyvo)
-- Banco: PostgreSQL 16
--
-- DDL completo do CORE da aplicacao (cadastro de pets, tutores, equipe
-- veterinaria, agendamento de consultas, prontuario, carteira de vacinacao,
-- triagem por questionario e tratamento em casa) + carga inicial de dados.
--
-- Este arquivo e apenas a documentacao/entrega da estrutura do banco: em
-- execucao normal, o schema e criado e versionado exclusivamente pelo Flyway
-- (src/main/resources/db/migration/V1..V8), a partir do boot da aplicacao.
-- Rodar este script manualmente e equivalente a rodar as 8 migrations em
-- sequencia contra um Postgres vazio.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. USUARIO / RESPONSAVEL (tutor) / MED_VET (veterinario) / ADMINISTRADOR
--    Heranca JOINED: "usuario" guarda os dados comuns, cada especializacao
--    guarda so o que lhe e proprio, ligada pela mesma chave primaria.
-- -----------------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tipo         VARCHAR(20)  NOT NULL,
    nome         VARCHAR(100) NOT NULL,
    email        VARCHAR(120) NOT NULL,
    cpf          VARCHAR(11)  NOT NULL,
    senha        VARCHAR(100),
    firebase_uid VARCHAR(128),
    ativo        BOOLEAN      NOT NULL DEFAULT TRUE,
    criado_em    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_usuario_email UNIQUE (email),
    CONSTRAINT uk_usuario_cpf UNIQUE (cpf),
    CONSTRAINT uk_usuario_firebase_uid UNIQUE (firebase_uid)
);
COMMENT ON TABLE usuario IS 'Conta unica de acesso. tipo discrimina RESPONSAVEL, VETERINARIO ou ADMIN; cada um tem tabela de especializacao propria.';
COMMENT ON COLUMN usuario.tipo IS 'Discriminador da heranca JOINED: RESPONSAVEL, VETERINARIO ou ADMIN.';
COMMENT ON COLUMN usuario.firebase_uid IS 'UID do Firebase Authentication usado pelo app mobile; NULL para contas so locais.';
COMMENT ON COLUMN usuario.ativo IS 'Veterinario removido e desativado, nunca apagado: prontuarios e consultas assinados por ele continuam no historico.';

CREATE TABLE responsavel (
    id_usuario BIGINT PRIMARY KEY,
    data_nasc  DATE,
    CONSTRAINT fk_responsavel_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);
COMMENT ON TABLE responsavel IS 'Especializacao de usuario: tutor(a) dos pets.';

CREATE TABLE med_vet (
    id_usuario    BIGINT      PRIMARY KEY,
    crmv          VARCHAR(20) NOT NULL,
    especialidade VARCHAR(80),
    CONSTRAINT fk_med_vet_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario),
    CONSTRAINT uk_med_vet_crmv UNIQUE (crmv)
);
COMMENT ON TABLE med_vet IS 'Especializacao de usuario: veterinario(a) da clinica.';

CREATE TABLE administrador (
    id_usuario BIGINT PRIMARY KEY,
    CONSTRAINT fk_administrador_usuario FOREIGN KEY (id_usuario) REFERENCES usuario (id_usuario)
);
COMMENT ON TABLE administrador IS 'Especializacao de usuario: administracao da clinica (cadastra/remove veterinarios).';

-- -----------------------------------------------------------------------------
-- 2. PET / PRONTUARIO
-- -----------------------------------------------------------------------------
CREATE TABLE pet (
    id_pet    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR(80) NOT NULL,
    descricao VARCHAR(255),
    raca      VARCHAR(80) NOT NULL,
    especie   VARCHAR(20) NOT NULL,
    data_nasc DATE        NOT NULL,
    id_resp   BIGINT      NOT NULL,
    CONSTRAINT fk_pet_responsavel FOREIGN KEY (id_resp) REFERENCES responsavel (id_usuario)
);
COMMENT ON TABLE pet IS 'CORE da aplicacao: animal cadastrado, sempre vinculado a um tutor.';
COMMENT ON COLUMN pet.especie IS 'CAO ou GATO - define quais vacinas/protocolos de triagem se aplicam.';

CREATE INDEX idx_pet_responsavel ON pet (id_resp);

CREATE TABLE prontuario (
    id_prontuario     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet            BIGINT       NOT NULL,
    id_med_vet        BIGINT       NOT NULL,
    id_consulta       BIGINT,
    procedimento      VARCHAR(255) NOT NULL,
    data_procedimento DATE         NOT NULL,
    local_atendimento VARCHAR(120) NOT NULL,
    CONSTRAINT fk_prontuario_pet FOREIGN KEY (id_pet) REFERENCES pet (id_pet),
    CONSTRAINT fk_prontuario_med_vet FOREIGN KEY (id_med_vet) REFERENCES med_vet (id_usuario)
);
COMMENT ON TABLE prontuario IS 'Registro clinico gerado ao concluir uma consulta; guarda quem atendeu, mesmo que o veterinario seja desativado depois.';

CREATE INDEX idx_prontuario_pet ON prontuario (id_pet);

-- -----------------------------------------------------------------------------
-- 3. CONSULTA (agendamento)
-- -----------------------------------------------------------------------------
CREATE TABLE consulta (
    id_consulta   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet        BIGINT       NOT NULL,
    id_med_vet    BIGINT       NOT NULL,
    data_hora     TIMESTAMP    NOT NULL,
    motivo        VARCHAR(255) NOT NULL,
    status        VARCHAR(20)  NOT NULL,
    observacoes   VARCHAR(500),
    criado_em     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em TIMESTAMP,
    CONSTRAINT fk_consulta_pet FOREIGN KEY (id_pet) REFERENCES pet (id_pet),
    CONSTRAINT fk_consulta_med_vet FOREIGN KEY (id_med_vet) REFERENCES med_vet (id_usuario)
);
COMMENT ON TABLE consulta IS 'Agendamento de atendimento. status segue o fluxo SOLICITADA -> CONFIRMADA -> EM_ATENDIMENTO -> CONCLUIDA (ou CANCELADA/NAO_COMPARECEU).';

CREATE INDEX idx_consulta_agenda ON consulta (id_med_vet, data_hora);
CREATE INDEX idx_consulta_pet ON consulta (id_pet);
CREATE INDEX idx_consulta_status ON consulta (status);

ALTER TABLE prontuario
    ADD CONSTRAINT fk_prontuario_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta);
ALTER TABLE prontuario ADD CONSTRAINT uk_prontuario_consulta UNIQUE (id_consulta);

-- -----------------------------------------------------------------------------
-- 4. VACINA / APLICACAO_VACINA (carteira de vacinacao)
-- -----------------------------------------------------------------------------
CREATE TABLE vacina (
    id_vacina       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome            VARCHAR(80) NOT NULL,
    especie         VARCHAR(20) NOT NULL,
    doses_protocolo INT         NOT NULL,
    intervalo_dias  INT         NOT NULL,
    meses_reforco   INT,
    CONSTRAINT uk_vacina_nome_especie UNIQUE (nome, especie)
);
COMMENT ON TABLE vacina IS 'Catalogo de vacinas por especie, com o protocolo de doses (quantidade, intervalo e periodicidade do reforco).';

CREATE TABLE aplicacao_vacina (
    id_aplicacao   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet         BIGINT      NOT NULL,
    id_vacina      BIGINT      NOT NULL,
    id_med_vet     BIGINT      NOT NULL,
    numero_dose    INT         NOT NULL,
    data_aplicacao DATE        NOT NULL,
    proxima_dose   DATE,
    lote           VARCHAR(40),
    CONSTRAINT fk_aplicacao_pet FOREIGN KEY (id_pet) REFERENCES pet (id_pet),
    CONSTRAINT fk_aplicacao_vacina FOREIGN KEY (id_vacina) REFERENCES vacina (id_vacina),
    CONSTRAINT fk_aplicacao_med_vet FOREIGN KEY (id_med_vet) REFERENCES med_vet (id_usuario),
    CONSTRAINT uk_aplicacao_dose UNIQUE (id_pet, id_vacina, numero_dose)
);
COMMENT ON TABLE aplicacao_vacina IS 'Dose efetivamente aplicada; proxima_dose e calculada pela API a partir do protocolo da vacina.';

CREATE INDEX idx_aplicacao_pet ON aplicacao_vacina (id_pet);
CREATE INDEX idx_aplicacao_proxima_dose ON aplicacao_vacina (proxima_dose);

-- -----------------------------------------------------------------------------
-- 5. TRIAGEM (questionario de urgencia)
-- -----------------------------------------------------------------------------
CREATE TABLE queixa (
    id_queixa            BIGINT       PRIMARY KEY,
    nome                 VARCHAR(80)  NOT NULL,
    descricao            VARCHAR(255) NOT NULL,
    categoria            VARCHAR(30)  NOT NULL,
    especie              VARCHAR(20),
    limite_urgente       INT          NOT NULL,
    limite_pouco_urgente INT          NOT NULL,
    ordem                INT          NOT NULL,
    CONSTRAINT uk_queixa_nome UNIQUE (nome)
);
COMMENT ON TABLE queixa IS 'Motivo inicial da triagem (ex.: vomito/diarreia, pele e coceira); especie NULL vale para cao e gato.';

CREATE TABLE pergunta_triagem (
    id_pergunta          BIGINT       PRIMARY KEY,
    id_queixa            BIGINT       NOT NULL,
    texto                VARCHAR(255) NOT NULL,
    ordem                INT          NOT NULL,
    obrigatoria          BOOLEAN      NOT NULL DEFAULT TRUE,
    id_opcao_dependencia BIGINT,
    CONSTRAINT fk_pergunta_queixa FOREIGN KEY (id_queixa) REFERENCES queixa (id_queixa)
);
COMMENT ON TABLE pergunta_triagem IS 'Pergunta do protocolo clinico. id fixo (nao gerado): o app mobile monta as telas em cima desses numeros.';

CREATE TABLE opcao_resposta (
    id_opcao     BIGINT       PRIMARY KEY,
    id_pergunta  BIGINT       NOT NULL,
    texto        VARCHAR(120) NOT NULL,
    peso         INT          NOT NULL DEFAULT 0,
    sinal_alerta BOOLEAN      NOT NULL DEFAULT FALSE,
    marcador     VARCHAR(40),
    ordem        INT          NOT NULL,
    CONSTRAINT fk_opcao_pergunta FOREIGN KEY (id_pergunta) REFERENCES pergunta_triagem (id_pergunta)
);
COMMENT ON COLUMN opcao_resposta.peso IS 'Pontuacao somada na avaliacao de urgencia; nunca exposta ao aplicativo mobile.';
COMMENT ON COLUMN opcao_resposta.sinal_alerta IS 'Se TRUE, classifica a triagem direto como EMERGENCIA, ignorando a soma de pesos.';

ALTER TABLE pergunta_triagem
    ADD CONSTRAINT fk_pergunta_dependencia
    FOREIGN KEY (id_opcao_dependencia) REFERENCES opcao_resposta (id_opcao);

CREATE TABLE orientacao_triagem (
    id_orientacao BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_queixa     BIGINT       NOT NULL,
    classificacao VARCHAR(20)  NOT NULL,
    texto         VARCHAR(255) NOT NULL,
    ordem         INT          NOT NULL,
    CONSTRAINT fk_orientacao_queixa FOREIGN KEY (id_queixa) REFERENCES queixa (id_queixa)
);
COMMENT ON TABLE orientacao_triagem IS 'Texto de orientacao devolvido ao tutor conforme a classificacao final da triagem.';

CREATE INDEX idx_orientacao_queixa ON orientacao_triagem (id_queixa, classificacao);

CREATE TABLE triagem (
    id_triagem    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet        BIGINT      NOT NULL,
    id_queixa     BIGINT      NOT NULL,
    pontuacao     INT         NOT NULL,
    classificacao VARCHAR(20) NOT NULL,
    acao_sugerida VARCHAR(20) NOT NULL,
    status        VARCHAR(20) NOT NULL,
    criado_em     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expira_em     TIMESTAMP   NOT NULL,
    id_consulta   BIGINT,
    CONSTRAINT fk_triagem_pet FOREIGN KEY (id_pet) REFERENCES pet (id_pet),
    CONSTRAINT fk_triagem_queixa FOREIGN KEY (id_queixa) REFERENCES queixa (id_queixa),
    CONSTRAINT fk_triagem_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta),
    CONSTRAINT uk_triagem_consulta UNIQUE (id_consulta)
);
COMMENT ON TABLE triagem IS 'Resultado da triagem respondida pelo tutor: pontuacao, classificacao de urgencia e a consulta que ela originou (se houver).';

CREATE INDEX idx_triagem_pet ON triagem (id_pet);
CREATE INDEX idx_triagem_fila ON triagem (classificacao, status);

CREATE TABLE resposta_triagem (
    id_resposta BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_triagem  BIGINT NOT NULL,
    id_pergunta BIGINT NOT NULL,
    id_opcao    BIGINT NOT NULL,
    CONSTRAINT fk_resposta_triagem FOREIGN KEY (id_triagem) REFERENCES triagem (id_triagem),
    CONSTRAINT fk_resposta_pergunta FOREIGN KEY (id_pergunta) REFERENCES pergunta_triagem (id_pergunta),
    CONSTRAINT fk_resposta_opcao FOREIGN KEY (id_opcao) REFERENCES opcao_resposta (id_opcao),
    CONSTRAINT uk_resposta_pergunta UNIQUE (id_triagem, id_pergunta)
);
COMMENT ON TABLE resposta_triagem IS 'Cada resposta escolhida pelo tutor em uma triagem.';

CREATE TABLE observacao_triagem (
    id_observacao BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_triagem    BIGINT       NOT NULL,
    texto         VARCHAR(255) NOT NULL,
    CONSTRAINT fk_observacao_triagem FOREIGN KEY (id_triagem) REFERENCES triagem (id_triagem)
);
COMMENT ON TABLE observacao_triagem IS 'Observacoes que a API deduz cruzando a triagem com o cadastro do pet (idade, vacinacao em atraso); dependem do estado do pet no momento e nao podem ser recalculadas depois.';

-- -----------------------------------------------------------------------------
-- 6. TRATAMENTO (prescricao domiciliar)
-- -----------------------------------------------------------------------------
CREATE TABLE tratamento (
    id_tratamento   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_pet          BIGINT       NOT NULL,
    id_med_vet      BIGINT       NOT NULL,
    id_consulta     BIGINT,
    medicamento     VARCHAR(120) NOT NULL,
    dosagem         VARCHAR(80)  NOT NULL,
    intervalo_horas INT          NOT NULL,
    duracao_dias    INT          NOT NULL,
    inicio_em       TIMESTAMP    NOT NULL,
    status          VARCHAR(20)  NOT NULL,
    observacoes     VARCHAR(500),
    criado_em       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    encerrado_em    TIMESTAMP,
    CONSTRAINT fk_tratamento_pet FOREIGN KEY (id_pet) REFERENCES pet (id_pet),
    CONSTRAINT fk_tratamento_med_vet FOREIGN KEY (id_med_vet) REFERENCES med_vet (id_usuario),
    CONSTRAINT fk_tratamento_consulta FOREIGN KEY (id_consulta) REFERENCES consulta (id_consulta)
);
COMMENT ON TABLE tratamento IS 'Prescricao domiciliar feita pelo veterinario (medicamento, dosagem, intervalo e duracao).';

CREATE INDEX idx_tratamento_pet ON tratamento (id_pet);
CREATE INDEX idx_tratamento_status ON tratamento (status);

CREATE TABLE dose_tratamento (
    id_dose          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_tratamento    BIGINT    NOT NULL,
    numero_dose      INT       NOT NULL,
    horario_previsto TIMESTAMP NOT NULL,
    confirmado_em    TIMESTAMP,
    CONSTRAINT fk_dose_tratamento FOREIGN KEY (id_tratamento) REFERENCES tratamento (id_tratamento),
    CONSTRAINT uk_dose_numero UNIQUE (id_tratamento, numero_dose)
);
COMMENT ON TABLE dose_tratamento IS 'Uma linha por horario previsto de administracao. A prescricao "12/12h por 7 dias" vira 14 registros concretos que o tutor confirma um a um; sem confirmacao ate a tolerancia, a dose e tratada como perdida na leitura.';

CREATE INDEX idx_dose_horario ON dose_tratamento (horario_previsto);

-- =============================================================================
-- CARGA INICIAL DE DADOS (equivalente as migrations V4, V6 e V8)
-- Senha de todas as contas de demonstracao: 123456 (hash BCrypt)
-- =============================================================================
INSERT INTO usuario (tipo, nome, email, cpf, senha) VALUES
    ('VETERINARIO', 'Dra. Camila Duarte', 'camila.duarte@ollipet.com', '98765432100', '$2a$10$zztCBVlHLsW6w.9BUUtAsurw7KlpNhZ19Ld9yYpZtzDVptGkGXRpe'),
    ('VETERINARIO', 'Dr. Rafael Nunes',   'rafael.nunes@ollipet.com',  '45678912311', '$2a$10$zztCBVlHLsW6w.9BUUtAsurw7KlpNhZ19Ld9yYpZtzDVptGkGXRpe'),
    ('RESPONSAVEL', 'Maria Silva',        'maria.silva@email.com',     '12345678901', '$2a$10$zztCBVlHLsW6w.9BUUtAsurw7KlpNhZ19Ld9yYpZtzDVptGkGXRpe'),
    ('RESPONSAVEL', 'Joao Pereira',       'joao.pereira@email.com',    '32165498700', '$2a$10$zztCBVlHLsW6w.9BUUtAsurw7KlpNhZ19Ld9yYpZtzDVptGkGXRpe'),
    ('ADMIN',       'Administracao Olli Pet', 'admin@ollipet.com',     '00011122233', '$2a$10$zztCBVlHLsW6w.9BUUtAsurw7KlpNhZ19Ld9yYpZtzDVptGkGXRpe');

INSERT INTO med_vet (id_usuario, crmv, especialidade)
SELECT id_usuario, 'SP-12345', 'Clinica Geral' FROM usuario WHERE email = 'camila.duarte@ollipet.com';
INSERT INTO med_vet (id_usuario, crmv, especialidade)
SELECT id_usuario, 'SP-54321', 'Dermatologia' FROM usuario WHERE email = 'rafael.nunes@ollipet.com';

INSERT INTO responsavel (id_usuario, data_nasc)
SELECT id_usuario, DATE '1995-08-10' FROM usuario WHERE email = 'maria.silva@email.com';
INSERT INTO responsavel (id_usuario, data_nasc)
SELECT id_usuario, DATE '1988-02-27' FROM usuario WHERE email = 'joao.pereira@email.com';

INSERT INTO administrador (id_usuario)
SELECT id_usuario FROM usuario WHERE email = 'admin@ollipet.com';

-- CORE da entrega: tabelas "pet" (>=5 linhas, exigido pela materia de banco) e
-- "responsavel", relacionadas por pet.id_resp -> responsavel.id_usuario.
INSERT INTO pet (nome, descricao, raca, especie, data_nasc, id_resp)
SELECT 'Thor', 'Cachorro docil, castrado', 'Golden Retriever', 'CAO', DATE '2021-03-15', id_usuario
FROM usuario WHERE email = 'maria.silva@email.com';
INSERT INTO pet (nome, descricao, raca, especie, data_nasc, id_resp)
SELECT 'Nina', 'Gata arisca com estranhos', 'Siames', 'GATO', DATE '2022-07-01', id_usuario
FROM usuario WHERE email = 'maria.silva@email.com';
INSERT INTO pet (nome, descricao, raca, especie, data_nasc, id_resp)
SELECT 'Bud', 'Idoso, acompanhamento cardiaco', 'Poodle', 'CAO', DATE '2019-11-20', id_usuario
FROM usuario WHERE email = 'joao.pereira@email.com';
INSERT INTO pet (nome, descricao, raca, especie, data_nasc, id_resp)
SELECT 'Mel', 'Filhote, primeira carteira de vacinas', 'SRD', 'CAO', DATE '2025-01-05', id_usuario
FROM usuario WHERE email = 'maria.silva@email.com';
INSERT INTO pet (nome, descricao, raca, especie, data_nasc, id_resp)
SELECT 'Frajola', 'Gato de rua resgatado, sociavel', 'SRD', 'GATO', DATE '2020-06-12', id_usuario
FROM usuario WHERE email = 'joao.pereira@email.com';

-- Protocolo: doses_protocolo = quantidade da serie inicial, intervalo_dias = espera entre elas,
-- meses_reforco = periodicidade do reforco depois da serie concluida.
INSERT INTO vacina (nome, especie, doses_protocolo, intervalo_dias, meses_reforco) VALUES
    ('V10',              'CAO',  3, 21, 12),
    ('Antirrabica',      'CAO',  1,  0, 12),
    ('Giardia',          'CAO',  2, 21, 12),
    ('Gripe Canina',     'CAO',  2, 21, 12),
    ('V4',               'GATO', 3, 21, 12),
    ('Antirrabica',      'GATO', 1,  0, 12),
    ('Leucemia Felina',  'GATO', 2, 21, 12);

-- Protocolos de triagem completos (4 queixas, 27 perguntas, opcoes e
-- orientacoes) ficam no Flyway V6__inserir_protocolos_triagem.sql: e conteudo
-- extenso demais para repetir aqui sem perder legibilidade. Rode a aplicacao
-- uma vez (Flyway aplica as 8 migrations automaticamente) para carga completa,
-- ou copie o conteudo de V6 direto no seu client SQL.
