# ─── Projeto ────────────────────────────────────────────────────────────────
# O projeto do Neon já nasce com uma branch `main`, que usamos como produção.
resource "neon_project" "autogiro" {
  name       = var.project_name
  org_id     = var.org_id
  region_id  = var.region
  pg_version = var.pg_version

  # Janela de point-in-time recovery. O free tier do Neon limita a 6 horas
  # (21600s); pedir mais faz a API rejeitar a criação do projeto.
  history_retention_seconds = var.history_retention_seconds

  branch {
    name          = "prod"
    database_name = var.database_name
    role_name     = var.role_name
  }
}

# ─── Branch de homologação ──────────────────────────────────────────────────
# O Neon versiona o banco como o Git: a branch de homologação nasce a partir da
# produção, com dados isolados e sem custo adicional de storage. É o que atende
# ao requisito "deploy automático das branches de homologação e produção".
resource "neon_branch" "homolog" {
  project_id = neon_project.autogiro.id
  parent_id  = neon_project.autogiro.branch[0].id
  name       = "homolog"
}

resource "neon_endpoint" "homolog" {
  project_id = neon_project.autogiro.id
  branch_id  = neon_branch.homolog.id
  type       = "read_write"

  # `suspend_timeout_seconds` não é declarado de propósito: o free tier do Neon
  # responde 412 "modifying the suspend interval is not permitted on this
  # account". O autosuspend continua ativo, com o intervalo padrão da conta.
}

# A role e o database NÃO são recriados aqui: ao nascer de `prod`, a branch
# `homolog` já herda ambos — `autogiro_app` e `autogiro`. Declará-los faria a API
# responder 409 ROLE_ALREADY_EXISTS.
#
# O data source abaixo apenas lê a senha da role herdada, para montar a connection
# string de homologação nos outputs.
# Senha da role na branch de producao, para montar a connection string do
# driver asyncpg nos outputs.
data "neon_branch_role_password" "prod" {
  project_id = neon_project.autogiro.id
  branch_id  = neon_project.autogiro.branch[0].id
  role_name  = var.role_name
}

data "neon_branch_role_password" "homolog" {
  project_id = neon_project.autogiro.id
  branch_id  = neon_branch.homolog.id
  role_name  = var.role_name

  depends_on = [neon_endpoint.homolog]
}

