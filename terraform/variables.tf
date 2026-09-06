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
