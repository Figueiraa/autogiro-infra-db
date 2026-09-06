output "project_id" {
  description = "ID do projeto no Neon."
  value       = neon_project.autogiro.id
}

output "prod_database_url" {
  description = "Connection string da branch de produção (driver psycopg)."
  value       = neon_project.autogiro.connection_uri
  sensitive   = true
}

output "homolog_host" {
  description = "Host do endpoint de homologação."
  value       = neon_endpoint.homolog.host
}

output "homolog_database_url" {
  description = "Connection string da branch de homologação (driver psycopg)."
  value = format(
    "postgresql://%s:%s@%s/%s?sslmode=require",
    neon_role.homolog.name,
    neon_role.homolog.password,
    neon_endpoint.homolog.host,
    neon_database.homolog.name,
  )
  sensitive = true
}

# A aplicação (SQLAlchemy assíncrono) usa o driver asyncpg; a Lambda usa
# psycopg. A diferença está apenas no prefixo do esquema da URL.
output "homolog_database_url_asyncpg" {
  description = "Connection string de homologação para o SQLAlchemy (asyncpg)."
  value = format(
    "postgresql+asyncpg://%s:%s@%s/%s?ssl=require",
    neon_role.homolog.name,
    neon_role.homolog.password,
    neon_endpoint.homolog.host,
    neon_database.homolog.name,
  )
  sensitive = true
}
