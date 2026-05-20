variable "resource_group_name" {
  type    = string
  default = "rg-dns-mysak-fun"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
  description = "Cloudflare API token with Zone:DNS:Edit and Zone:Zone:Read permissions for mysak.fun"
}

variable "azure_seip_nginx_ip" {
  type        = string
  default     = "20.103.44.124"
  description = "nginx-ingress LoadBalancer IP from azure-seip cluster (terraform output nginx_ingress_ip)"
}
