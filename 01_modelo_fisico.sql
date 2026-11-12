BEGIN;

CREATE SCHEMA banco_alimentos;
SET LOCAL search_path TO banco_alimentos, public;

CREATE TABLE doador (
    id_doador integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(150) NOT NULL,
    tipo_pessoa char(2) NOT NULL CHECK (tipo_pessoa IN ('PF', 'PJ')),
    cpf_cnpj varchar(14) NOT NULL UNIQUE,
    telefone varchar(20),
    email varchar(254),
    CHECK (
        (tipo_pessoa = 'PF' AND cpf_cnpj ~ '^[0-9]{11}$')
        OR (tipo_pessoa = 'PJ' AND cpf_cnpj ~ '^[0-9]{14}$')
    )
);

CREATE TABLE doacao (
    id_doacao integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_doador integer NOT NULL REFERENCES doador,
    data_recebimento date NOT NULL,
    observacao text
);

CREATE TABLE alimento (
    id_alimento integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(120) NOT NULL,
    categoria varchar(80) NOT NULL,
    unidade_medida varchar(10) NOT NULL,
    UNIQUE (nome, unidade_medida)
);

CREATE TABLE lote (
    id_lote integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_doacao integer NOT NULL REFERENCES doacao,
    id_alimento integer NOT NULL REFERENCES alimento,
    codigo_lote varchar(40) NOT NULL UNIQUE,
    data_validade date NOT NULL,
    quantidade numeric(12,3) NOT NULL CHECK (quantidade > 0 AND quantidade <> 'NaN'),
    status varchar(12) NOT NULL DEFAULT 'LIBERADO' CHECK (status IN ('LIBERADO', 'BLOQUEADO'))
);

CREATE TABLE coleta (
    id_coleta integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_doacao integer NOT NULL UNIQUE REFERENCES doacao,
    data_agendada date NOT NULL,
    data_realizada date,
    status varchar(12) NOT NULL DEFAULT 'AGENDADA'
        CHECK (status IN ('AGENDADA', 'REALIZADA', 'CANCELADA')),
    CHECK ((status = 'REALIZADA') = (data_realizada IS NOT NULL))
);

CREATE TABLE perfil (
    id_perfil integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(60) NOT NULL UNIQUE,
    descricao text
);

CREATE TABLE usuario (
    id_usuario integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_perfil integer NOT NULL REFERENCES perfil,
    nome varchar(150) NOT NULL,
    email varchar(254) NOT NULL UNIQUE,
    senha varchar(255) NOT NULL,
    ativo boolean NOT NULL DEFAULT true
);

CREATE TABLE instituicao (
    id_instituicao integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome varchar(150) NOT NULL,
    cnpj varchar(14) NOT NULL UNIQUE CHECK (cnpj ~ '^[0-9]{14}$'),
    telefone varchar(20),
    email varchar(254),
    endereco text NOT NULL
);

CREATE TABLE entrega (
    id_entrega integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_instituicao integer NOT NULL REFERENCES instituicao,
    data_prevista date NOT NULL,
    status varchar(12) NOT NULL DEFAULT 'REALIZADA' CHECK (status = 'REALIZADA'),
    data_realizada date NOT NULL
);

CREATE TABLE lote_entrega (
    id_lote integer REFERENCES lote,
    id_entrega integer REFERENCES entrega,
    quantidade_entregue numeric(12,3) NOT NULL
        CHECK (quantidade_entregue > 0 AND quantidade_entregue <> 'NaN'),
    PRIMARY KEY (id_lote, id_entrega)
);

CREATE TABLE estoque_lote (
    id_lote integer PRIMARY KEY REFERENCES lote,
    saldo numeric(12,3) NOT NULL CHECK (saldo >= 0 AND saldo <> 'NaN')
);

CREATE INDEX idx_doacao_doador ON doacao (id_doador);
CREATE INDEX idx_doacao_recebimento ON doacao (data_recebimento);
CREATE INDEX idx_lote_doacao ON lote (id_doacao);
CREATE INDEX idx_lote_alimento ON lote (id_alimento);
CREATE INDEX idx_lote_validade ON lote (data_validade);
CREATE INDEX idx_entrega_instituicao ON entrega (id_instituicao);
CREATE INDEX idx_entrega_realizada ON entrega (data_realizada);
CREATE INDEX idx_lote_entrega_entrega ON lote_entrega (id_entrega);
CREATE INDEX idx_usuario_perfil ON usuario (id_perfil);

COMMIT;
