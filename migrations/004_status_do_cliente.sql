-- ═══════════════════════════════════════════════════════════════════════════
-- Status do cliente
--
-- O enunciado da Fase 3 pede que a function serverless "consulte a existência
-- e o status do cliente na base de dados". Só havia a verificação de
-- existência: a tabela `clients` não modelava cliente inativo.
--
-- Casos reais que isso cobre numa rede de oficinas: cliente com pendência
-- financeira, cadastro suspenso a pedido, ou registro criado por engano que não
-- pode ser apagado porque tem histórico de ordens de serviço.
--
-- Idempotente como as demais: `IF NOT EXISTS` na coluna e no índice.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE clients
    ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

COMMENT ON COLUMN clients.is_active IS
    'Cliente apto a autenticar. FALSE bloqueia a emissão de token pela Lambda.';

-- A Lambda filtra por cpf_cnpj e lê is_active na mesma consulta; o índice
-- parcial serve o caso comum (cliente ativo) sem indexar as linhas bloqueadas.
CREATE INDEX IF NOT EXISTS ix_clients_ativos
    ON clients (cpf_cnpj)
    WHERE is_active;

-- ─── Cliente bloqueado para demonstração ────────────────────────────────────
-- Transportes Lima ME entra como inativo, para que o vídeo possa mostrar o
-- caminho de recusa: CPF válido, cliente existente, mas sem permissão de acesso.
UPDATE clients
SET is_active = FALSE
WHERE cpf_cnpj = '94789277879';
