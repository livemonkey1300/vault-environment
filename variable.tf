variable "environment" {
  description = "The environment for which to deploy resources (e.g., dev, staging, prod)"
  type        = list(string)
  default     = ["staging" , "prod" , "dev" ]
}

# variable "tfc_workspace" {
#   description = "Terraform Cloud workspace name"
#   type        = string
# }


variable "google_region" {
  description = "The Google Cloud region to deploy resources in"
  type        = string
  default     = "northamerica-northeast1"
}

variable "google_project" {
  description = "The Google Cloud project ID"
  type        = string
  default     = "dev-ops-275615"
  
}