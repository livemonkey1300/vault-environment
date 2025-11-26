variable "environment" {
  description = "The environment for which to deploy resources (e.g., dev, staging, prod)"
  type        = list(string)
  default     = ["staging" , "prod" , "dev" ]
}

variable "tfc_workspace" {
  description = "Terraform Cloud workspace name"
  type        = string
}