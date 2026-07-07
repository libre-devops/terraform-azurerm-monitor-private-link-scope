<!--
  Header for the complete example README. Edit this file, then run `just docs`
  (or ./Sort-LdoTerraform.ps1 -IncludeExamples) to regenerate the section between the markers.
  The example's main.tf is embedded into the README automatically (see .terraform-docs.yml).
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="200">
    </picture>
  </a>
</div>

# Complete example

The full private telemetry path: a scope carrying a workspace, an Application Insights
component, and a data collection endpoint as scoped services, fronted by one azuremonitor
private endpoint resolved through the five privatelink monitor zones. The environment comes from the Terraform workspace
(`terraform.workspace`), not a variable. Run it with `just e2e complete`, which applies the stack
then always destroys it.

[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)

<!-- BEGIN_TF_DOCS -->
## Example configuration

```hcl
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

  # The group is referenced by its literal name, so the graph edge must be explicit or this
  # races the group's creation.
  depends_on = [module.rg]
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
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.0.0, < 5.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ampls"></a> [ampls](#module\_ampls) | ../../ | n/a |
| <a name="module_app_insights"></a> [app\_insights](#module\_app\_insights) | libre-devops/application-insights/azurerm | ~> 4.0 |
| <a name="module_log_analytics"></a> [log\_analytics](#module\_log\_analytics) | libre-devops/log-analytics-workspace/azurerm | ~> 4.0 |
| <a name="module_network"></a> [network](#module\_network) | libre-devops/network/azurerm | ~> 4.0 |
| <a name="module_private_dns"></a> [private\_dns](#module\_private\_dns) | libre-devops/private-dns-zone/azurerm | ~> 4.0 |
| <a name="module_private_endpoint"></a> [private\_endpoint](#module\_private\_endpoint) | libre-devops/private-endpoint/azurerm | ~> 4.0 |
| <a name="module_rg"></a> [rg](#module\_rg) | libre-devops/rg/azurerm | ~> 4.0 |
| <a name="module_tags"></a> [tags](#module\_tags) | libre-devops/tags/azurerm | ~> 4.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_monitor_data_collection_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_data_collection_endpoint) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deployed_branch"></a> [deployed\_branch](#input\_deployed\_branch) | Git branch the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_branch. | `string` | `""` | no |
| <a name="input_deployed_repo"></a> [deployed\_repo](#input\_deployed\_repo) | Repository URL the deployment came from. Auto-filled in CI from TF\_VAR\_deployed\_repo. | `string` | `""` | no |
| <a name="input_loc"></a> [loc](#input\_loc) | Outfix: short Azure region code used in resource names (for example uks). | `string` | `"uks"` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Map of short region codes to Azure region slugs. | `map(string)` | <pre>{<br/>  "eus": "eastus",<br/>  "euw": "westeurope",<br/>  "uks": "uksouth",<br/>  "ukw": "ukwest"<br/>}</pre> | no |
| <a name="input_short"></a> [short](#input\_short) | Infix: short product code used in resource names. | `string` | `"ldo"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_link_scope_ids"></a> [private\_link\_scope\_ids](#output\_private\_link\_scope\_ids) | Map of scope name to id. |
| <a name="output_scoped_service_ids"></a> [scoped\_service\_ids](#output\_scoped\_service\_ids) | Map of scoped service name to id. |
<!-- END_TF_DOCS -->
