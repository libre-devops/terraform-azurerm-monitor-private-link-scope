locals {
  location   = lookup(var.regions, var.loc, "uksouth")
  rg_name    = "rg-${var.short}-${var.loc}-${terraform.workspace}-001"
  law_name   = "log-${var.short}-${var.loc}-${terraform.workspace}-001"
  ampls_name = "ampls-${var.short}-${var.loc}-${terraform.workspace}-001"
}

module "tags" {
  source  = "libre-devops/tags/azurerm"
  version = "~> 4.0"

  cost_centre     = "1888/67"
  owner           = "platform@example.com"
  deployed_branch = var.deployed_branch
  deployed_repo   = var.deployed_repo
}

module "rg" {
  source  = "libre-devops/rg/azurerm"
  version = "~> 4.0"

  resource_groups = [{ name = local.rg_name, location = local.location, tags = module.tags.tags }]
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

# Minimal call: one scope with one workspace scoped into it. Access modes stay Open (the
# migration-friendly default) until every producer is scoped and a private endpoint fronts it.
module "ampls" {
  source = "../../"

  resource_group_id = module.rg.ids[local.rg_name]
  tags              = module.tags.tags

  private_link_scopes = {
    (local.ampls_name) = {}
  }

  scoped_services = {
    "scoped-law-central" = {
      scope              = local.ampls_name
      linked_resource_id = module.log_analytics.workspace_ids[local.law_name]
    }
  }
}
