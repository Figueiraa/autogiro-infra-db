-- ═══════════════════════════════════════════════════════════════════════════
-- AutoGiro — índices de performance
--
-- Cada índice aqui existe por causa de uma consulta concreta da aplicação.
-- Índice sem consulta que o justifique é custo de escrita sem retorno.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Autenticação ──────────────────────────────────────────────────────────
-- A constraint UNIQUE de clients.cpf_cnpj já cria o índice usado pela Lambda
-- de autenticação, portanto não há índice adicional aqui.

-- ─── Listagem de veículos de um cliente ────────────────────────────────────
-- GET /api/v1/clients/{id}/vehicles
CREATE INDEX IF NOT EXISTS ix_vehicles_client_id
    ON vehicles (client_id);

-- ─── Listagem de ordens de serviço ─────────────────────────────────────────
-- A listagem principal filtra por status e ordena por data de criação.
-- Índice composto cobre o filtro e a ordenação em uma única varredura.
CREATE INDEX IF NOT EXISTS ix_service_orders_status_created
    ON service_orders (status, created_at DESC);

-- Histórico de OS por cliente e por veículo.
CREATE INDEX IF NOT EXISTS ix_service_orders_client_id
    ON service_orders (client_id);

CREATE INDEX IF NOT EXISTS ix_service_orders_vehicle_id
    ON service_orders (vehicle_id);

-- ─── Dashboards de observabilidade ─────────────────────────────────────────
-- "Volume diário de ordens de serviço" (requisito R10) agrupa por dia.
CREATE INDEX IF NOT EXISTS ix_service_orders_created_at
    ON service_orders (created_at DESC);

-- "Tempo médio de execução por status" percorre apenas OS já concluídas;
-- o índice parcial evita indexar as linhas ainda em aberto.
CREATE INDEX IF NOT EXISTS ix_service_orders_completed_at
    ON service_orders (completed_at)
    WHERE completed_at IS NOT NULL;

-- ─── Composição da OS ──────────────────────────────────────────────────────
-- Carregamento dos itens e peças ao abrir uma ordem de serviço.
CREATE INDEX IF NOT EXISTS ix_service_order_items_order_id
    ON service_order_items (service_order_id);

CREATE INDEX IF NOT EXISTS ix_service_order_parts_order_id
    ON service_order_parts (service_order_id);

-- ─── Estoque ───────────────────────────────────────────────────────────────
-- Alerta de peças com estoque baixo. Índice parcial: só interessam as peças
-- que já estão perto de acabar.
CREATE INDEX IF NOT EXISTS ix_parts_stock_baixo
    ON parts (stock_quantity)
    WHERE stock_quantity <= 5;

COMMIT;
