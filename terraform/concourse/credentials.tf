# To rotate password, use terraform taint random_password.<name> and then terraform apply
resource "random_password" "postgres" {
  length  = 16
  special = false
}

resource "random_password" "concourse_admin" {
  length  = 16
  special = false
}

resource "local_sensitive_file" "concourse_env" {
  lifecycle {
    precondition {
      condition     = local.git_client_id != "" && local.git_client_secret != ""
      error_message = "You need to set both GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET variables."
    }
  }

  content  = <<-ENV
    CONCOURSE_POSTGRES_PASSWORD=${random_password.postgres.result}
    CONCOURSE_ADMIN_PWD=${random_password.concourse_admin.result}
    CONCOURSE_EXTERNAL_URL=https://${var.hostname}.${var.dns_zone_fqdn}
    CONCOURSE_GITHUB_CLIENT_ID=${local.git_client_id}
    CONCOURSE_GITHUB_CLIENT_SECRET=${local.git_client_secret}
  ENV
  filename = "${path.module}/.concourse.env"
}

# Below construct retrieves last used variable value from my own remote state
# so that users don't need to input it again when doing unrelated changes
data "terraform_remote_state" "my_state" {
  backend = "gcs"

  config = {
    bucket = "arp-concourse-state"
    prefix = "terraform/state"
  }

  # Empty defaults for intial seeding
  defaults = {
    GITHUB_CLIENT_ID     = ""
    GITHUB_CLIENT_SECRET = ""
  }
}

locals {
  git_client_id     = var.GITHUB_CLIENT_ID != "" ? var.GITHUB_CLIENT_ID : data.terraform_remote_state.my_state.outputs.GITHUB_CLIENT_ID
  git_client_secret = var.GITHUB_CLIENT_SECRET != "" ? var.GITHUB_CLIENT_SECRET : data.terraform_remote_state.my_state.outputs.GITHUB_CLIENT_SECRET
}

output "GITHUB_CLIENT_ID" {
  value       = local.git_client_id
  description = "Github client ID from oAuth application config in git to allow concourse use git as auth."
  sensitive   = true
}

output "GITHUB_CLIENT_SECRET" {
  value       = local.git_client_secret
  description = "Github client secret from oAuth application config in git to allow concourse use git as auth"
  sensitive   = true
}
