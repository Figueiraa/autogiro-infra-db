# ─── Projeto ────────────────────────────────────────────────────────────────
# O projeto do Neon já nasce com uma branch `main`, que usamos como produção.
resource "neon_project" "autogiro" {
  name       = var.project_name
  org_id     = var.org_id
  region_id  = var.region
  pg_version = var.pg_version

  # Suspende o compute após inatividade, preservando a cota de CU-horas.
  history_retention_seconds = 86400 # 1 dia (suficiente no free tier)

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
  project_id              = neon_project.autogiro.id
  branch_id               = neon_branch.homolog.id
  type                    = "read_write"
  suspend_timeout_seconds = var.autosuspend_seconds
}

resource "neon_role" "homolog" {
  project_id = neon_project.autogiro.id
  branch_id  = neon_branch.homolog.id
  name       = var.role_name
}

resource "neon_database" "homolog" {
  project_id = neon_project.autogiro.id
  branch_id  = neon_branch.homolog.id
  owner_name = neon_role.homolog.name
  name       = var.database_name
}
