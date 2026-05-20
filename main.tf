terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "dns" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_dns_zone" "mysak_fun" {
  name                = "mysak.fun"
  resource_group_name = azurerm_resource_group.dns.name
}


resource "azurerm_dns_a_record" "llm" {
  name                = "llm"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  records             = ["20.230.229.131"]
}

resource "azurerm_dns_cname_record" "grafana_llm" {
  name                = "grafana.llm"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = "llm.mysak.fun"
}


resource "azurerm_dns_cname_record" "cloudfire" {
  name                = "cloudfire"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = "mi-3-cloudfire-y29hf3.azurewebsites.net"
}

resource "azurerm_dns_txt_record" "cloudfire_verification" {
  name                = "asuid.cloudfire"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record {
    value = "24C4FD8D3A8507E43D386A411379665BC15579939C271A26E15AE5643A8A540A"
  }
}

data "terraform_remote_state" "mongo" {
  backend = "azurerm"
  config = {
    resource_group_name  = "az-mongo-tfstate-rg"
    storage_account_name = "azumongotfstate"
    container_name       = "tfstate"
    key                  = "az-mongo.tfstate"
    use_azuread_auth     = true
  }
}

resource "azurerm_dns_cname_record" "docs" {
  name                = "docs"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = data.terraform_remote_state.mongo.outputs.container_app_fqdn
}

resource "azurerm_dns_txt_record" "docs_verification" {
  name                = "asuid.docs"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record {
    value = data.terraform_remote_state.mongo.outputs.container_app_domain_verification_id
  }
}

data "terraform_remote_state" "aws_penny" {
  backend = "s3"
  config = {
    bucket = "seip-terraform-state-dev"
    key    = "aws-penny/terraform.tfstate"
    region = "eu-central-1"
  }
}

resource "azurerm_dns_cname_record" "aws_penny" {
  name                = "aws-penny"
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = data.terraform_remote_state.aws_penny.outputs.app_runner_service_url
}

resource "azurerm_dns_cname_record" "aws_penny_cert_validation" {
  for_each = {
    for r in data.terraform_remote_state.aws_penny.outputs.custom_domain_validation_records :
    r.name => r
  }

  name                = replace(each.value.name, ".mysak.fun", "")
  zone_name           = azurerm_dns_zone.mysak_fun.name
  resource_group_name = azurerm_resource_group.dns.name
  ttl                 = 300
  record              = each.value.value
}

output "nameservers" {
  value       = azurerm_dns_zone.mysak_fun.name_servers
  description = "Nameservery ke zkopírování do WEDOS"
}

# ── Cloudflare ────────────────────────────────────────────────────────────────

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "mysak_fun" {
  name = "mysak.fun"
}

resource "cloudflare_record" "azure_seip" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  name    = "azure-seip"
  value   = var.azure_seip_nginx_ip
  type    = "A"
  ttl     = 1 # 1 = automatic (required when proxied)
  proxied = true
}

resource "cloudflare_zone_settings_override" "mysak_fun" {
  zone_id = data.cloudflare_zone.mysak_fun.id
  settings {
    ssl = "full" # origin has valid Let's Encrypt cert; use "strict" to also verify chain
  }
}
