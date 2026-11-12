BEGIN;

SET LOCAL search_path TO banco_alimentos, public;

INSERT INTO doador (nome, tipo_pessoa, cpf_cnpj, telefone, email)
VALUES ('Mercado Exemplo', 'PJ', '11111111000111', '43900000001', 'mercado@example.com'),
       ('Produtor Exemplo', 'PF', '22222222222', '43900000002', 'produtor@example.com');

INSERT INTO instituicao (nome, cnpj, endereco)
VALUES ('Cozinha Solidária Exemplo', '33333333000133', 'Rua Exemplo, 100, Londrina'),
       ('Creche Exemplo', '44444444000144', 'Rua Exemplo, 200, Londrina');

INSERT INTO alimento (nome, categoria, unidade_medida)
VALUES ('Arroz', 'Grãos', 'kg'),
       ('Feijão', 'Leguminosas', 'kg'),
       ('Leite', 'Laticínios', 'L');

INSERT INTO perfil (nome, descricao)
VALUES ('Operador', 'Cadastro operacional');

INSERT INTO usuario (id_perfil, nome, email, senha, ativo)
SELECT id_perfil, 'Operador Exemplo', 'operador@example.com', 'SEM_CREDENCIAL_DE_TESTE', false
FROM perfil WHERE nome = 'Operador';

SELECT registrar_doacao(
    (SELECT id_doador FROM doador WHERE cpf_cnpj = '11111111000111'),
    CURRENT_DATE, 'Doação de exemplo do mercado',
    jsonb_build_array(
        jsonb_build_object('id_alimento', (SELECT id_alimento FROM alimento WHERE nome = 'Arroz'),
            'codigo_lote', 'ARZ-001', 'data_validade', CURRENT_DATE + 30, 'quantidade', 50),
        jsonb_build_object('id_alimento', (SELECT id_alimento FROM alimento WHERE nome = 'Feijão'),
            'codigo_lote', 'FEJ-001', 'data_validade', CURRENT_DATE + 15, 'quantidade', 30),
        jsonb_build_object('id_alimento', (SELECT id_alimento FROM alimento WHERE nome = 'Leite'),
            'codigo_lote', 'LET-001', 'data_validade', CURRENT_DATE + 3,
            'quantidade', 10, 'status', 'BLOQUEADO')
    )
);

SELECT registrar_doacao(
    (SELECT id_doador FROM doador WHERE cpf_cnpj = '22222222222'),
    CURRENT_DATE - 10, 'Lote que venceu após o recebimento',
    jsonb_build_array(
        jsonb_build_object('id_alimento', (SELECT id_alimento FROM alimento WHERE nome = 'Leite'),
            'codigo_lote', 'LET-002', 'data_validade', CURRENT_DATE - 1, 'quantidade', 15)
    )
);

INSERT INTO coleta (id_doacao, data_agendada, data_realizada, status)
SELECT id_doacao, data_recebimento, data_recebimento, 'REALIZADA'
FROM doacao WHERE observacao = 'Doação de exemplo do mercado';

SELECT registrar_entrega(
    (SELECT id_instituicao FROM instituicao WHERE cnpj = '33333333000133'),
    CURRENT_DATE, CURRENT_DATE,
    jsonb_build_array(
        jsonb_build_object('id_lote', (SELECT id_lote FROM lote WHERE codigo_lote = 'ARZ-001'),
            'quantidade_entregue', 20),
        jsonb_build_object('id_lote', (SELECT id_lote FROM lote WHERE codigo_lote = 'FEJ-001'),
            'quantidade_entregue', 10)
    )
);

SELECT registrar_entrega(
    (SELECT id_instituicao FROM instituicao WHERE cnpj = '44444444000144'),
    CURRENT_DATE, CURRENT_DATE,
    jsonb_build_array(
        jsonb_build_object('id_lote', (SELECT id_lote FROM lote WHERE codigo_lote = 'ARZ-001'),
            'quantidade_entregue', 5)
    )
);

COMMIT;
