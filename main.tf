terraform { 
  cloud { 
    # organization = "gcp-live"
    # workspaces {
    #   tags = ["gcp-live", "vault"]
    # }
  } 
required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "5.4.0"
    }
}
}

provider "vault" {}

resource "vault_mount" "kv" {
    for_each = toset(var.environment)
    path        = "${each.value}"
    type        = "kv"
    options     = { version = "2" }
    description = "KV Version 2 secret engine mount for ${each.value} environment"
}


resource "tls_private_key" "ssh" {
  for_each = toset(var.environment)
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Generate SSH key pair
resource "vault_generic_secret" "ssh_keypair" {
    for_each = toset(var.environment)
    path = "${vault_mount.kv[each.key].path}/ssh-keys"
    
    data_json = jsonencode({
        public_key  = tls_private_key.ssh[each.key].public_key_openssh
        private_key = tls_private_key.ssh[each.key].private_key_pem
    })
}


# Create GitHub Actions service account policy
resource "vault_policy" "github_actions_policy" {
  for_each = toset(var.environment)
  name = "${each.value}-github-actions-policy"
  
  policy = <<EOT
path "${vault_mount.kv[each.key].path}/ssh-keys" {
  capabilities = ["read"]
}
path "token/data/*" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOT
}

# Create AppRole for GitHub Actions
resource "vault_auth_backend" "approle" {
    type = "approle"
    path = "approle"
}

resource "vault_approle_auth_backend_role" "github_actions" {
    for_each       = toset(var.environment)
    backend        = vault_auth_backend.approle.path
    role_name      = "github-actions-${each.value}"
    token_policies = [vault_policy.github_actions_policy[each.key].name]
    token_ttl      = 600
    token_max_ttl  = 1200
}

resource "vault_approle_auth_backend_role_secret_id" "github_actions" {
  for_each  = toset(var.environment)
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.github_actions[each.key].role_name
}
