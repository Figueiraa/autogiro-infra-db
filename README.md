# autogiro-infra-db

> **AutoGiro** · Repositório 3 de 4 — Tech Challenge Fase 3 (13SOAT)

Infraestrutura do **banco de dados gerenciado** do AutoGiro — Neon PostgreSQL — com Terraform,
migrations e a documentação do modelo de dados.

## Propósito

- Provisiona o projeto, os roles e os databases no **Neon**.
- Cria **branches de banco** para homologação e produção.
- Mantém as **migrations** versionadas e a modelagem documentada.

## Tecnologias

| Item | Tecnologia |
|---|---|
| Banco | PostgreSQL 17 |
| Provedor | [Neon](https://neon.com) — serverless, free tier permanente |
| IaC | Terraform (provider `kislerdm/neon`) |
| Migrations | SQL puro, idempotente |
| CI/CD | GitHub Actions |

## Por que PostgreSQL

Justificativa formal exigida pelo requisito R11:

| Critério | Análise |
|---|---|
| **Modelo relacional** | O domínio é fortemente relacional: um cliente possui veículos, que possuem ordens de serviço, compostas por itens e peças. Integridade referencial é requisito, não conveniência. |
| **Transações ACID** | Abrir uma OS grava a ordem, seus itens, suas peças e dá baixa no estoque. Ou tudo acontece, ou nada — sem transação, o estoque diverge. |
| **Constraints declarativas** | `CHECK` de estoque não-negativo e de coerência temporal protegem as invariantes mesmo sob escrita concorrente, independentemente da aplicação. |
| **Tipo ENUM nativo** | A máquina de estados da OS vira um tipo do banco: valores fora do domínio são rejeitados pelo próprio PostgreSQL. |
| **Índices parciais** | Consultas de dashboard (OS concluídas, peças com estoque baixo) usam índices parciais — recurso que o MySQL não oferece. |
| **Ecossistema** | SQLAlchemy com `asyncpg` na API e `psycopg` na Lambda, ambos maduros. |

**Por que não NoSQL:** o acesso é por relacionamento e agregação (tempo médio por status, volume
diário), não por chave. Um documento denormalizado exigiria duplicar cliente e veículo em cada OS,
com custo de consistência sem ganho de escala — o volume de uma rede de oficinas não justifica.

**Por que Neon:** free tier permanente sem cartão de crédito, PostgreSQL 17 sem modificações e
**branches de banco** — que resolvem elegantemente a separação homologação/produção exigida pelo
requisito R5.

## Modelo ER

```
┌─────────────────┐         ┌─────────────────┐
│    clients      │         │    vehicles     │
├─────────────────┤         ├─────────────────┤
│ id          PK  │────┐    │ id          PK  │
│ cpf_cnpj    UQ  │    │    │ plate       UQ  │
│ name            │    └───►│ client_id   FK  │
│ phone           │  1    N │ brand           │
│ email           │         │ model           │
│ address         │         │ year            │
└─────────────────┘         └────────┬────────┘
        │                            │
        │ 1                        1 │
        │                            │
        │      ┌─────────────────────▼──────┐
        │   N  │     service_orders         │
        └─────►├────────────────────────────┤
               │ id                     PK  │
               │ number                 UQ  │
               │ client_id              FK  │
               │ vehicle_id             FK  │
               │ status  service_order_status
               │ total_budget               │
               │ created_at / started_at    │
               │ completed_at / delivered_at│
               └────┬──────────────────┬────┘
                  1 │                1 │
                    │ N                │ N
      ┌─────────────▼──────┐  ┌────────▼─────────────┐
      │ service_order_items│  │ service_order_parts  │
      ├────────────────────┤  ├──────────────────────┤
      │ service_order_id FK│  │ service_order_id  FK │
      │ service_type_id  FK│  │ part_id           FK │
      │ quantity           │  │ quantity             │
      │ unit_price         │  │ unit_price           │
      └─────────┬──────────┘  └──────────┬───────────┘
              N │                      N │
                │ 1                    1 │
      ┌─────────▼──────────┐  ┌──────────▼───────────┐
      │   service_types    │  │        parts         │
      ├────────────────────┤  ├──────────────────────┤
      │ id             PK  │  │ id               PK  │
      │ name           UQ  │  │ name                 │
      │ price              │  │ unit_price           │
      │ estimated_duration │  │ stock_quantity       │
      └────────────────────┘  └──────────────────────┘

┌─────────────────┐
│      users      │   Operação interna (atendentes e mecânicos).
├─────────────────┤   Distinto de `clients`, que se autentica por
│ id          PK  │   CPF através da Lambda.
│ username    UQ  │
│ email       UQ  │
│ password_hash   │
└─────────────────┘
```

### Relacionamentos

| Relação | Cardinalidade | `ON DELETE` | Razão |
|---|---|---|---|
| `clients` → `vehicles` | 1:N | `RESTRICT` | Apagar cliente com veículos perderia o histórico |
| `clients` → `service_orders` | 1:N | `RESTRICT` | Idem |
| `vehicles` → `service_orders` | 1:N | `RESTRICT` | Idem |
| `service_orders` → `service_order_items` | 1:N | `CASCADE` | Itens não existem sem a OS |
| `service_orders` → `service_order_parts` | 1:N | `CASCADE` | Idem |
| `service_types` → `service_order_items` | 1:N | `RESTRICT` | Preserva OS históricas |
| `parts` → `service_order_parts` | 1:N | `RESTRICT` | Idem |

`service_order_items` e `service_order_parts` são tabelas associativas N:N com atributos próprios
(`quantity` e `unit_price`). O preço é **copiado** para a OS em vez de referenciado: o valor
cobrado precisa refletir o momento da venda, não o preço atual do catálogo.

### Ajustes feitos na Fase 3

| Ajuste | Motivo |
|---|---|
| `status` virou **ENUM nativo** | Antes `VARCHAR`; agora o banco rejeita estados fora do domínio |
| `CHECK` em `cpf_cnpj` | Garante 11 ou 14 dígitos sem máscara — formato que a Lambda consulta |
| `CHECK` de estoque não-negativo | Protege a invariante sob escrita concorrente |
| `CHECK` de coerência temporal | `delivered_at ≥ completed_at ≥ started_at` |
| `ON DELETE` explícito | Antes implícito; agora a intenção está declarada |
| **9 índices** | Derivados de consultas concretas (ver `002_indices.sql`) |
| `TIMESTAMPTZ` | Substitui `TIMESTAMP`: correção em operação multi-unidade |

## Migrations

| Arquivo | Conteúdo |
|---|---|
| [`001_schema_inicial.sql`](migrations/001_schema_inicial.sql) | Tipos, tabelas e constraints |
| [`002_indices.sql`](migrations/002_indices.sql) | Índices de performance |

Todas são **idempotentes** (`IF NOT EXISTS`) — reaplicar não gera erro. A pipeline valida isso
aplicando cada migration duas vezes em um PostgreSQL efêmero.

## Uso

```bash
export NEON_API_KEY="sua-api-key"        # PowerShell: $env:NEON_API_KEY = "..."
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

terraform -chdir=terraform init
terraform -chdir=terraform apply

# Aplicar as migrations
DB_URL=$(terraform -chdir=terraform output -raw homolog_database_url)
for f in migrations/*.sql; do psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"; done
```

### Testando as migrations sem o Neon

```bash
docker run -d --name pg -e POSTGRES_PASSWORD=test -e POSTGRES_DB=autogiro \
  -p 5432:5432 postgres:17-alpine

for f in migrations/*.sql; do
  docker exec -i pg psql -U postgres -d autogiro -v ON_ERROR_STOP=1 < "$f"
done

docker exec pg psql -U postgres -d autogiro -c '\dt'
```

## Ambientes

O Neon versiona o banco como o Git. Cada branch tem dados isolados, sem custo adicional de storage:

| Branch Git | Branch Neon | Quando |
|---|---|---|
| `develop` | `homolog` | Push em develop |
| `main` | `prod` | Push em main |

## Custo

Free tier permanente do Neon: **0,5 GB de storage** e **100 CU-horas/mês**, sem cartão de crédito.
O compute suspende após 5 minutos de inatividade (`autosuspend_seconds`), preservando a cota.
