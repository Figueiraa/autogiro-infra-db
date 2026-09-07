# Backend do Terraform state — HCP Terraform (Terraform Cloud).
#
# Este é o repositório onde o state importa mais: `neon_project` não é idempotente
# por nome, então um state descartado faria o `apply` seguinte criar um SEGUNDO
# projeto no Neon — e o free tier permite apenas um.
#
# Plano gratuito do HCP: 500 recursos, sem cartão de crédito.
#
# `tags` em vez de `name`: o workspace é escolhido em tempo de execução pela
# pipeline (`TF_WORKSPACE=autogiro-infra-db-homolog` ou `-prod`).
#
# Autenticação: `TF_TOKEN_app_terraform_io` no ambiente (a pipeline injeta a partir
# do secret `TF_API_TOKEN`) ou `terraform login` na máquina.
terraform {
  cloud {
    organization = "autogiro"

    workspaces {
      tags = ["autogiro-infra-db"]
    }
  }
}
