BEGIN;

SET LOCAL search_path TO banco_alimentos, public;

CREATE FUNCTION iniciar_estoque() RETURNS trigger
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
DECLARE
    recebimento date;
BEGIN
    SELECT data_recebimento INTO recebimento FROM doacao WHERE id_doacao = NEW.id_doacao;
    IF NEW.data_validade < recebimento THEN
        RAISE EXCEPTION 'Validade anterior ao recebimento do lote %', NEW.codigo_lote;
    END IF;
    INSERT INTO estoque_lote (id_lote, saldo) VALUES (NEW.id_lote, NEW.quantidade);
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lote_estoque
AFTER INSERT ON lote
FOR EACH ROW EXECUTE FUNCTION iniciar_estoque();

CREATE FUNCTION baixar_estoque() RETURNS trigger
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
DECLARE
    lote_atual lote%ROWTYPE;
    recebimento date;
    realizacao date;
BEGIN
    SELECT * INTO lote_atual FROM lote WHERE id_lote = NEW.id_lote FOR NO KEY UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Lote % inexistente', NEW.id_lote;
    END IF;
    SELECT data_recebimento INTO recebimento FROM doacao WHERE id_doacao = lote_atual.id_doacao;
    SELECT data_realizada INTO realizacao FROM entrega WHERE id_entrega = NEW.id_entrega;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Entrega % inexistente', NEW.id_entrega;
    END IF;
    IF realizacao < recebimento OR realizacao > CURRENT_DATE THEN
        RAISE EXCEPTION 'Data da entrega incompatível com o recebimento ou com a data atual';
    END IF;
    IF lote_atual.status = 'BLOQUEADO' THEN
        RAISE EXCEPTION 'Lote % bloqueado', lote_atual.codigo_lote;
    END IF;
    IF lote_atual.data_validade < CURRENT_DATE THEN
        RAISE EXCEPTION 'Lote % vencido', lote_atual.codigo_lote;
    END IF;

    UPDATE estoque_lote
    SET saldo = saldo - NEW.quantidade_entregue
    WHERE id_lote = NEW.id_lote AND saldo >= NEW.quantidade_entregue;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Saldo insuficiente no lote %', lote_atual.codigo_lote;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lote_entrega_baixa
AFTER INSERT ON lote_entrega
FOR EACH ROW EXECUTE FUNCTION baixar_estoque();

CREATE FUNCTION conferir_lotes_doacao() RETURNS trigger
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM lote WHERE id_doacao = NEW.id_doacao) THEN
        RAISE EXCEPTION 'A doação % precisa ter ao menos um lote', NEW.id_doacao;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_doacao_com_lotes
AFTER INSERT ON doacao DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION conferir_lotes_doacao();

CREATE FUNCTION conferir_lotes_entrega() RETURNS trigger
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM lote_entrega WHERE id_entrega = NEW.id_entrega) THEN
        RAISE EXCEPTION 'A entrega % precisa ter ao menos um lote', NEW.id_entrega;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_entrega_com_lotes
AFTER INSERT ON entrega DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION conferir_lotes_entrega();

CREATE FUNCTION preservar_movimentacao() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Os registros operacionais de % são preservados para rastreabilidade', TG_TABLE_NAME;
END;
$$;

CREATE TRIGGER trg_preservar_doacao
BEFORE UPDATE OF id_doacao, id_doador, data_recebimento OR DELETE ON doacao
FOR EACH ROW EXECUTE FUNCTION preservar_movimentacao();

CREATE TRIGGER trg_preservar_lote
BEFORE UPDATE OF id_lote, id_doacao, id_alimento, codigo_lote, data_validade, quantidade OR DELETE ON lote
FOR EACH ROW EXECUTE FUNCTION preservar_movimentacao();

CREATE TRIGGER trg_preservar_entrega
BEFORE UPDATE OR DELETE ON entrega
FOR EACH ROW EXECUTE FUNCTION preservar_movimentacao();

CREATE TRIGGER trg_preservar_lote_entrega
BEFORE UPDATE OR DELETE ON lote_entrega
FOR EACH ROW EXECUTE FUNCTION preservar_movimentacao();

CREATE FUNCTION registrar_doacao(
    p_doador integer, p_recebimento date, p_observacao text, p_lotes jsonb
) RETURNS integer
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
DECLARE
    nova_doacao integer;
BEGIN
    IF jsonb_typeof(p_lotes) IS DISTINCT FROM 'array' OR p_lotes = '[]'::jsonb THEN
        RAISE EXCEPTION 'Informe pelo menos um lote para a doação';
    END IF;
    IF p_recebimento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data do recebimento não pode ser futura';
    END IF;

    INSERT INTO doacao (id_doador, data_recebimento, observacao)
    VALUES (p_doador, p_recebimento, p_observacao)
    RETURNING id_doacao INTO nova_doacao;

    INSERT INTO lote (id_doacao, id_alimento, codigo_lote, data_validade, quantidade, status)
    SELECT nova_doacao, item.id_alimento, item.codigo_lote, item.data_validade,
           item.quantidade, COALESCE(item.status, 'LIBERADO')
    FROM jsonb_to_recordset(p_lotes) AS item(
        id_alimento integer, codigo_lote varchar, data_validade date,
        quantidade numeric, status varchar
    );

    RETURN nova_doacao;
END;
$$;

CREATE FUNCTION registrar_entrega(
    p_instituicao integer, p_prevista date, p_realizada date, p_lotes jsonb
) RETURNS integer
LANGUAGE plpgsql SET search_path TO banco_alimentos, pg_temp AS $$
DECLARE
    nova_entrega integer;
BEGIN
    IF jsonb_typeof(p_lotes) IS DISTINCT FROM 'array' OR p_lotes = '[]'::jsonb THEN
        RAISE EXCEPTION 'Informe pelo menos um lote para a entrega';
    END IF;

    PERFORM id_lote
    FROM lote
    WHERE id_lote IN (
        SELECT item.id_lote
        FROM jsonb_to_recordset(p_lotes) AS item(id_lote integer)
    )
    ORDER BY id_lote
    FOR NO KEY UPDATE;

    INSERT INTO entrega (id_instituicao, data_prevista, data_realizada)
    VALUES (p_instituicao, p_prevista, p_realizada)
    RETURNING id_entrega INTO nova_entrega;

    INSERT INTO lote_entrega (id_lote, id_entrega, quantidade_entregue)
    SELECT item.id_lote, nova_entrega, item.quantidade_entregue
    FROM jsonb_to_recordset(p_lotes) AS item(id_lote integer, quantidade_entregue numeric);

    RETURN nova_entrega;
END;
$$;

CREATE VIEW vw_estoque_por_validade AS
SELECT l.id_lote, l.codigo_lote, a.nome AS alimento, a.unidade_medida,
       l.data_validade, l.data_validade - CURRENT_DATE AS dias_ate_vencimento,
       l.quantidade AS quantidade_recebida, s.saldo,
       CASE
           WHEN l.data_validade < CURRENT_DATE THEN 'VENCIDO'
           WHEN l.status = 'BLOQUEADO' THEN 'BLOQUEADO'
           WHEN s.saldo = 0 THEN 'ESGOTADO'
           ELSE 'DISPONIVEL'
       END AS situacao
FROM lote l
JOIN alimento a USING (id_alimento)
JOIN estoque_lote s USING (id_lote);

CREATE VIEW vw_doacoes_por_periodo AS
SELECT date_trunc('month', d.data_recebimento::timestamp)::date AS mes,
       a.id_alimento, a.nome AS alimento, a.unidade_medida,
       count(DISTINCT d.id_doacao) AS total_doacoes,
       sum(l.quantidade) AS quantidade_doada
FROM doacao d
JOIN lote l USING (id_doacao)
JOIN alimento a USING (id_alimento)
GROUP BY 1, a.id_alimento, a.nome, a.unidade_medida;

COMMIT;
