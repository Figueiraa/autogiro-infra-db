-- ═══════════════════════════════════════════════════════════════════════════
-- AutoGiro — schema inicial
--
-- Migration idempotente: pode ser reaplicada sem erro (IF NOT EXISTS).
-- Alvo: PostgreSQL 17 (Neon).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── Tipos ─────────────────────────────────────────────────────────────────
-- Status da Ordem de Serviço. Modelado como ENUM nativo (e não VARCHAR) para
-- que o próprio banco rejeite valores fora da máquina de estados do domínio.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'service_order_status') THEN
        CREATE TYPE service_order_status AS ENUM (
            'RECEBIDA',
            'EM_DIAGNOSTICO',
            'AGUARDANDO_APROVACAO',
            'EM_EXECUCAO',
            'FINALIZADA',
            'ENTREGUE',
            'ORCAMENTO_RECUSADO'
        );
    END IF;
END$$;

-- ─── clients ───────────────────────────────────────────────────────────────
-- O CPF/CNPJ é armazenado apenas com dígitos (sem máscara). A Lambda de
-- autenticação consulta por esta coluna, daí o índice único.
CREATE TABLE IF NOT EXISTS clients (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    cpf_cnpj    VARCHAR(18)  NOT NULL,
    phone       VARCHAR(20),
    email       VARCHAR(255),
    address     VARCHAR(500),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_clients_cpf_cnpj UNIQUE (cpf_cnpj),
    -- Aceita 11 dígitos (CPF) ou 14 (CNPJ), sempre sem máscara.
    CONSTRAINT ck_clients_cpf_cnpj_digitos CHECK (cpf_cnpj ~ '^[0-9]{11}$|^[0-9]{14}$')
);

-- ─── vehicles ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vehicles (
    id          SERIAL PRIMARY KEY,
    plate       VARCHAR(10)  NOT NULL,
    brand       VARCHAR(100) NOT NULL,
    model       VARCHAR(100) NOT NULL,
    year        INTEGER      NOT NULL,
    client_id   INTEGER      NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_vehicles_plate UNIQUE (plate),
    -- RESTRICT: impede apagar um cliente que ainda tem veículos, preservando
    -- o histórico de ordens de serviço.
    CONSTRAINT fk_vehicles_client FOREIGN KEY (client_id)
        REFERENCES clients (id) ON DELETE RESTRICT,
    CONSTRAINT ck_vehicles_year CHECK (year BETWEEN 1900 AND 2100)
);

-- ─── service_types ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS service_types (
    id                          SERIAL PRIMARY KEY,
    name                        VARCHAR(255)   NOT NULL,
    description                 TEXT,
    price                       NUMERIC(10, 2) NOT NULL,
    estimated_duration_minutes  INTEGER        NOT NULL DEFAULT 60,
    created_at                  TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT uq_service_types_name UNIQUE (name),
    CONSTRAINT ck_service_types_price CHECK (price >= 0),
    CONSTRAINT ck_service_types_duration CHECK (estimated_duration_minutes > 0)
);

-- ─── parts ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS parts (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(255)   NOT NULL,
    description     TEXT,
    unit_price      NUMERIC(10, 2) NOT NULL,
    stock_quantity  INTEGER        NOT NULL DEFAULT 0,
    unit            VARCHAR(20)    NOT NULL DEFAULT 'un',
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT ck_parts_unit_price CHECK (unit_price >= 0),
    -- Estoque não pode ficar negativo: a baixa de peças é validada no domínio,
    -- mas a constraint garante a invariante mesmo em escrita concorrente.
    CONSTRAINT ck_parts_stock CHECK (stock_quantity >= 0)
);

-- ─── service_orders ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS service_orders (
    id            SERIAL PRIMARY KEY,
    number        VARCHAR(20)          NOT NULL,
    vehicle_id    INTEGER              NOT NULL,
    client_id     INTEGER              NOT NULL,
    status        service_order_status NOT NULL DEFAULT 'RECEBIDA',
    notes         TEXT,
    total_budget  NUMERIC(10, 2)       NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ          NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ          NOT NULL DEFAULT now(),
    started_at    TIMESTAMPTZ,
    completed_at  TIMESTAMPTZ,
    delivered_at  TIMESTAMPTZ,

    CONSTRAINT uq_service_orders_number UNIQUE (number),
    CONSTRAINT fk_service_orders_vehicle FOREIGN KEY (vehicle_id)
        REFERENCES vehicles (id) ON DELETE RESTRICT,
    CONSTRAINT fk_service_orders_client FOREIGN KEY (client_id)
        REFERENCES clients (id) ON DELETE RESTRICT,
    CONSTRAINT ck_service_orders_total_budget CHECK (total_budget >= 0),
    -- Coerência temporal do ciclo de vida da OS.
    CONSTRAINT ck_service_orders_completed_after_started
        CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at),
    CONSTRAINT ck_service_orders_delivered_after_completed
        CHECK (delivered_at IS NULL OR completed_at IS NULL OR delivered_at >= completed_at)
);

-- ─── service_order_items (serviços executados na OS) ───────────────────────
CREATE TABLE IF NOT EXISTS service_order_items (
    id                SERIAL PRIMARY KEY,
    service_order_id  INTEGER        NOT NULL,
    service_type_id   INTEGER        NOT NULL,
    quantity          INTEGER        NOT NULL DEFAULT 1,
    unit_price        NUMERIC(10, 2) NOT NULL,

    -- CASCADE: os itens não existem sem a OS que os contém.
    CONSTRAINT fk_soi_service_order FOREIGN KEY (service_order_id)
        REFERENCES service_orders (id) ON DELETE CASCADE,
    CONSTRAINT fk_soi_service_type FOREIGN KEY (service_type_id)
        REFERENCES service_types (id) ON DELETE RESTRICT,
    CONSTRAINT ck_soi_quantity CHECK (quantity > 0),
    CONSTRAINT ck_soi_unit_price CHECK (unit_price >= 0)
);

-- ─── service_order_parts (peças aplicadas na OS) ───────────────────────────
CREATE TABLE IF NOT EXISTS service_order_parts (
    id                SERIAL PRIMARY KEY,
    service_order_id  INTEGER        NOT NULL,
    part_id           INTEGER        NOT NULL,
    quantity          INTEGER        NOT NULL DEFAULT 1,
    unit_price        NUMERIC(10, 2) NOT NULL,

    CONSTRAINT fk_sop_service_order FOREIGN KEY (service_order_id)
        REFERENCES service_orders (id) ON DELETE CASCADE,
    CONSTRAINT fk_sop_part FOREIGN KEY (part_id)
        REFERENCES parts (id) ON DELETE RESTRICT,
    CONSTRAINT ck_sop_quantity CHECK (quantity > 0),
    CONSTRAINT ck_sop_unit_price CHECK (unit_price >= 0)
);

-- ─── users (operação interna da oficina) ───────────────────────────────────
-- Atendentes e mecânicos. Distinto de `clients`, que se autentica por CPF
-- através da Lambda.
CREATE TABLE IF NOT EXISTS users (
    id             SERIAL PRIMARY KEY,
    username       VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    is_active      BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email UNIQUE (email)
);

COMMIT;
