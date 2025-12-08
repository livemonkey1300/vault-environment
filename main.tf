terraform { 
  cloud { 
  } 
required_providers {
    vault = {
      source = "hashicorp/vault"
      version = "5.4.0"
    }
    digitalocean = {
        source = "digitalocean/digitalocean"
        version = "~> 2.0"
    }
}
}

provider "vault" {}

data "vault_generic_secret" "digitalocean_token" {
  path = "token/digitalocean"
}

provider "digitalocean" {
  token = jsondecode(data.vault_generic_secret.digitalocean_token.data_json)["token"]
}



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

#Create DigitalOcean SSH key using the generated public key
resource "digitalocean_ssh_key" "vault_generated" {
    for_each = toset(var.environment)
    name       = "vault-generated-key-${each.value}"
    public_key = jsondecode(vault_generic_secret.ssh_keypair[each.key].data_json)["public_key"]
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

# Store AppRole credentials in Vault KV store
resource "vault_generic_secret" "github_actions_credentials" {
    for_each = toset(var.environment)
    path     = "${vault_mount.kv[each.key].path}/github-actions"
    
    data_json = jsonencode({
        role_id   = vault_approle_auth_backend_role.github_actions[each.key].role_id
        secret_id = vault_approle_auth_backend_role_secret_id.github_actions[each.key].secret_id
    })
    
    depends_on = [vault_approle_auth_backend_role_secret_id.github_actions]
}

# Output the role IDs and secret IDs for pipeline use
output "github_actions_role_ids" {
    value = {
        for env in var.environment : env => vault_approle_auth_backend_role.github_actions[env].role_id
    }
    description = "AppRole role IDs for GitHub Actions authentication"
}

output "github_actions_secret_ids" {
    value = {
        for env in var.environment : env => vault_approle_auth_backend_role_secret_id.github_actions[env].secret_id
    }
    description = "AppRole secret IDs for GitHub Actions authentication"
    sensitive = true
}

