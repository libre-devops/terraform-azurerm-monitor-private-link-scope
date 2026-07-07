locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-002"
  vnet_name  = "vnet-${var.short}-${var.loc}-${terraform.workspace}-002"
  law_name   = "log-${var.short}-${var.loc}-${terraform.workspace}-002"
  appi_name  = "appi-${var.short}-${var.loc}-${terraform.workspace}-002"
  dce_name   = "dce-${var.short}-${var.loc}-${terraform.workspace}-002"
  ampls_name = "ampls-${var.short}-${var.loc}-${terraform.workspace}-002"

  # The five zones Azure Monitor private link resolution rides on.
  monitor_zones = [
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.blob.core.windows.net",
  ]
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
  additional_tags = { Application = "terraform-azurerm-monitor-private-link-scope" }
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
}

module "network" {
  source  = "libre-devops/network/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  vnet_name     = local.vnet_name
  address_space = ["10.90.0.0/24"]

  subnets = {
    "snet-pep-${local.vnet_name}" = {
      address_prefixes = ["10.90.0.0/27"]
    }
  }
}

module "log_analytics" {
  source  = "libre-devops/log-analytics-workspace/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  log_analytics_workspaces = {
    (local.law_name) = {}
  }
}

module "app_insights" {
  source  = "libre-devops/application-insights/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  application_insights = {
    (local.appi_name) = {
      application_type = "web"
      workspace_id     = module.log_analytics.workspace_ids[local.law_name]
    }
  }
}

# Support resource: agent and ingestion-API telemetry enters through a DCE, so it belongs in
# the scope alongside the workspace and component (compose the data-collection module for the
# full rules surface).
resource "azurerm_monitor_data_collection_endpoint" "this" {
  resource_group_name = local.rg_name
  location            = local.location
  tags                = module.tags.tags

  name = local.dce_name
}

# Complete call: the scope carries all three telemetry producers. Access modes stay Open so
# unscoped resources keep working during migration; flip to PrivateOnly to hard-enforce once
# everything is scoped.
module "ampls" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  tags              = module.tags.tags

  private_link_scopes = {
    (local.ampls_name) = {
      ingestion_access_mode = "Open"
      query_access_mode     = "Open"
    }
  }

  scoped_services = {
    "scoped-law-central" = {
      scope              = local.ampls_name
      linked_resource_id = module.log_analytics.workspace_ids[local.law_name]
    }

    "scoped-appi-web" = {
      scope              = local.ampls_name
      linked_resource_id = module.app_insights.ids[local.appi_name]
    }

    "scoped-dce-agents" = {
      scope              = local.ampls_name
      linked_resource_id = azurerm_monitor_data_collection_endpoint.this.id
    }
  }
}

# The five privatelink monitor zones, all linked to the vnet.
module "private_dns" {
  source  = "libre-devops/private-dns-zone/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  tags              = module.tags.tags

  private_dns_zones = { for z in local.monitor_zones : z => {} }

  default_vnet_links = {
    "link-${local.vnet_name}" = {
      virtual_network_id = module.network.vnet_id
    }
  }
}

# One private endpoint onto the scope (subresource azuremonitor) fans out to every scoped
# service; the zone group carries all five zones.
module "private_endpoint" {
  source  = "libre-devops/private-endpoint/azurerm"
  version = "~> 4.0"

  resource_group_id = module.rg.ids[local.rg_name]
  location          = local.location
  tags              = module.tags.tags

  private_dns_zone_ids = { for z in local.monitor_zones : z => module.private_dns.private_dns_zone_ids[z] }

  private_endpoints = {
    azuremonitor = {
      subnet_id           = module.network.subnet_ids["snet-pep-${local.vnet_name}"]
      auto_dns_zone_group = true

      private_service_connection = {
        private_connection_resource_id = module.ampls.private_link_scope_ids[local.ampls_name]
        subresource_names              = ["azuremonitor"]
      }
    }
  }
}
