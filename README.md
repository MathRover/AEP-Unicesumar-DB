# Banco de Dados do Banco de Alimentos de Londrina

**UniCesumar · Engenharia de Software · 4º semestre**  
**Banco de Dados · AEP 2026.2 · Segunda entrega**  
**Integrantes** 
<br>
Maria Eduarda Bueno de Azevedo RA: 25177957-2, 
<br>
Matheus Rover da Silva RA: 25032458-2,
<br>
Samuel de Oliveira Campos RA: 25235501-2

## 1 Modelo físico

O modelo físico segue o diagrama relacional da primeira entrega, incluindo a tabela associativa `lote_entrega`. Uma doação tem ao menos um lote e pode ter uma coleta. Cada lote identifica um alimento. Uma entrega realizada destina-se a uma instituição e inclui um ou mais lotes. A chave composta de `lote_entrega` identifica a quantidade retirada de cada lote em uma entrega.

O PostgreSQL gera as chaves primárias numéricas. As chaves estrangeiras preservam os relacionamentos, e as restrições `UNIQUE` e `CHECK` validam a unicidade de documentos e códigos, os estados e as quantidades. As quantidades usam três casas decimais e são acompanhadas pela unidade de medida do alimento. Os índices cobrem as principais chaves estrangeiras e datas usadas nas consultas.

Foi acrescentada a tabela `estoque_lote` para manter o saldo operacional de cada lote. O saldo é inicializado a partir da quantidade recebida e atualizado pelos gatilhos de movimentação. Os registros de entrega representam distribuições realizadas. Os campos que identificam e quantificam as movimentações ficam protegidos contra edição e exclusão, preservando o histórico.

## 2 Funções, gatilhos e visões

| Objeto | Operação |
| --- | --- |
| `registrar_doacao` | Registra o recebimento e seus lotes na mesma transação |
| `registrar_entrega` | Registra a instituição, a entrega e as retiradas na mesma transação |
| `trg_lote_estoque` | Valida a validade em relação ao recebimento e inicializa o saldo do lote |
| `trg_lote_entrega_baixa` | Valida as datas e o estado do lote, depois deduz a quantidade se houver saldo |
| `trg_doacao_com_lotes` e `trg_entrega_com_lotes` | Conferem no fim da transação se o registro tem ao menos um lote |
| `vw_estoque_por_validade` | Mostra saldo, dias até o vencimento e situação por lote |
| `vw_doacoes_por_periodo` | Totaliza doações e quantidades por mês, alimento e unidade |

A função de entrega bloqueia as linhas dos lotes em ordem de ID. A baixa usa um `UPDATE` condicionado ao saldo disponível. Quando duas transações pedem o mesmo lote, a segunda espera a primeira terminar e o saldo é conferido novamente. Uma falha em qualquer item desfaz o registro da entrega e as baixas da operação.

## 3 Execução e resultados

Em um banco PostgreSQL de teste, abra e execute os arquivos na ordem abaixo. Os três primeiros preparam o esquema e a massa de teste para a primeira execução. O quarto pode ser consultado repetidamente.

| Arquivo | Conteúdo |
| --- | --- |
| `01_modelo_fisico.sql` | DDL, índices, chaves e restrições |
| `02_objetos.sql` | Funções, gatilhos e visões |
| `03_dados_teste.sql` | Dados fictícios de doações, coletas e entregas |
| `04_consultas.sql` | Ranking de doações no mês, saldo por validade, distribuição no trimestre e rastreabilidade por lote |

No terminal, a partir da pasta extraída e com um banco de teste chamado `aep_banco_alimentos` já criado, a execução pode ser feita com o `psql`.

```text
psql -d aep_banco_alimentos -v ON_ERROR_STOP=1 -f 01_modelo_fisico.sql -f 02_objetos.sql -f 03_dados_teste.sql -f 04_consultas.sql
```

| Lote | Recebido | Distribuído | Saldo após a carga | Situação |
| --- | ---: | ---: | ---: | --- |
| ARZ-001 | 50 kg | 25 kg | 25 kg | Disponível |
| FEJ-001 | 30 kg | 10 kg | 20 kg | Disponível |
| LET-001 | 10 L | 0 L | 10 L | Bloqueado |
| LET-002 | 15 L | 0 L | 15 L | Vencido |

A validação executou os quatro scripts no PostgreSQL 18.6. Também verificou a rejeição de lote vencido, lote bloqueado e saldo insuficiente, além da reversão integral de uma entrega com um item válido e outro sem saldo. Em duas conexões concorrentes, cada uma solicitou 20 kg de um lote com 25 kg. A primeira entrega foi registrada, a segunda foi rejeitada e o saldo final ficou em 5 kg.

## Referências

BANCO DE ALIMENTOS DE LONDRINA. *Projeto de Banco de Dados — primeira entrega*. UniCesumar, 2026. p. 2–3.

POSTGRESQL GLOBAL DEVELOPMENT GROUP. *PostgreSQL 16 Documentation — CREATE TRIGGER*. Seção Description. Disponível em https://www.postgresql.org/docs/16/sql-createtrigger.html. Acesso em 12 nov. 2026.
