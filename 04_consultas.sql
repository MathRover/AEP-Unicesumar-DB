SELECT alimento, unidade_medida, total_doacoes, quantidade_doada,
       DENSE_RANK() OVER (
           PARTITION BY unidade_medida ORDER BY quantidade_doada DESC
       ) AS posicao_na_unidade
FROM banco_alimentos.vw_doacoes_por_periodo
WHERE mes = date_trunc('month', CURRENT_DATE::timestamp)::date
ORDER BY unidade_medida, posicao_na_unidade, alimento;

SELECT codigo_lote, alimento, unidade_medida, saldo,
       data_validade, dias_ate_vencimento, situacao
FROM banco_alimentos.vw_estoque_por_validade
ORDER BY data_validade, codigo_lote;

SELECT i.nome AS instituicao, a.nome AS alimento, a.unidade_medida,
       SUM(le.quantidade_entregue) AS quantidade_distribuida
FROM banco_alimentos.entrega e
JOIN banco_alimentos.instituicao i USING (id_instituicao)
JOIN banco_alimentos.lote_entrega le USING (id_entrega)
JOIN banco_alimentos.lote l USING (id_lote)
JOIN banco_alimentos.alimento a USING (id_alimento)
WHERE e.data_realizada >= date_trunc('quarter', CURRENT_DATE::timestamp)::date
  AND e.data_realizada < date_trunc('quarter', CURRENT_DATE::timestamp)::date + INTERVAL '3 months'
GROUP BY i.id_instituicao, i.nome, a.id_alimento, a.nome, a.unidade_medida
ORDER BY instituicao, alimento;

SELECT l.codigo_lote, a.nome AS alimento, d.data_recebimento, dr.nome AS doador,
       i.nome AS instituicao, e.data_realizada, le.quantidade_entregue, a.unidade_medida
FROM banco_alimentos.lote l
JOIN banco_alimentos.alimento a USING (id_alimento)
JOIN banco_alimentos.doacao d USING (id_doacao)
JOIN banco_alimentos.doador dr USING (id_doador)
LEFT JOIN banco_alimentos.lote_entrega le USING (id_lote)
LEFT JOIN banco_alimentos.entrega e USING (id_entrega)
LEFT JOIN banco_alimentos.instituicao i USING (id_instituicao)
ORDER BY l.codigo_lote, e.data_realizada, e.id_entrega;
