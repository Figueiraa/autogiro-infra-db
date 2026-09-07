variable "history_retention_seconds" {
  description = <<-EOT
    Janela de point-in-time recovery, em segundos. O free tier do Neon aceita no
    máximo 21600 (6 horas) — valores maiores fazem a API rejeitar a criação.
  EOT
  type        = number
  default     = 21600

  validation {
    condition     = var.history_retention_seconds <= 21600
    error_message = "O free tier do Neon limita a retenção a 21600 segundos (6 horas)."
  }
}

variable "org_id" {
  description = <<-EOT
    Identificador da organização no Neon (formato `org-xxxx-xxxx-00000000`).
    A API do Neon passou a exigi-lo na criação de projetos. Encontre em
    Organization settings, ou na URL do console.
  EOT
  type        = string
}

variable "project_name" {
  description = "Nome do projeto no Neon."
  type        = string
  default     = "autogiro"
}

variable "region" {
  description = "Região do Neon (formato aws-<região>)."
  type        = string
  default     = "aws-us-east-2"
}

variable "pg_version" {
  description = "Versão do PostgreSQL."
  type        = number
  default     = 17
}

variable "database_name" {
  description = "Nome do banco de dados."
  type        = string
  default     = "autogiro"
}

variable "role_name" {
  description = "Role de aplicação usada pela API e pela Lambda."
  type        = string
  default     = "autogiro_app"
}

variable "autosuspend_seconds" {
  description = <<-EOT
    Tempo de inatividade antes de suspender o compute. O free tier do Neon
    concede 100 CU-horas por mês; suspender rápido preserva essa cota.
  EOT
  type        = number
  default     = 300
}
