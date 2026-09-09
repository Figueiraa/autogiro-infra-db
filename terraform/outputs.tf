output "project_id" {
  description = "ID do projeto no Neon."
  value       = neon_project.autogiro.id
}

output "prod_database_url" {
  description = "Connection string da branch de produção (driver psycopg)."
  value       = neon_project.autogiro.connection_uri
  sensitive   = true
}

# A aplicacao usa SQLAlchemy assincrono (driver asyncpg) e a Lambda usa psycopg.
# Muda o prefixo do esquema e o nome do parametro de SSL, entao cada consumidor
# precisa da sua propria versao da string.
output "prod_database_url_asyncpg" {
  description = "Connection string de produção para o SQLAlchemy (asyncpg)."

  # Monta a partir das partes em vez de manipular a string do provider: um
  # `replace` sobre `connection_uri` dependeria do formato exato devolvido pelo
  # Neon, e uma mudanca no sufixo produziria silenciosamente uma URL sem SSL.
  value = format(
    "postgresql+asyncpg://%s:%s@%s/%s?ssl=require",
    var.role_name,
    data.neon_branch_role_password.prod.password,
    neon_project.autogiro.database_host,
    var.database_name,
  )
  sensitive = true
}

output "homolog_host" {
  description = "Host do endpoint de homologação."
  value       = neon_endpoint.homolog.host
}

output "homolog_database_url" {
  description = "Connection string da branch de homologação (driver psycopg)."
  value = format(
    "postgresql://%s:%s@%s/%s?sslmode=require",
    var.role_name,
    data.neon_branch_role_password.homolog.password,
    neon_endpoint.homolog.host,
    var.database_name,
  )
  sensitive = true
}

# A aplicação (SQLAlchemy assíncrono) usa o driver asyncpg; a Lambda usa
# psycopg. A diferença está apenas no prefixo do esquema da URL.
output "homolog_database_url_asyncpg" {
  description = "Connection string de homologação para o SQLAlchemy (asyncpg)."
  value = format(
    "postgresql+asyncpg://%s:%s@%s/%s?ssl=require",
    var.role_name,
    data.neon_branch_role_password.homolog.password,
    neon_endpoint.homolog.host,
    var.database_name,
  )
  sensitive = true
}
