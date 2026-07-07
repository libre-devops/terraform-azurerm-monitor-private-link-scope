# AMPLS is a regionless (global) resource: no location argument anywhere in the family.
locals {
  rg_name = provider::azurerm::parse_resource_id(var.resource_group_id)["resource_group_name"]
}

resource "azurerm_monitor_private_link_scope" "this" {
  for_each = var.private_link_scopes

  resource_group_name = local.rg_name
  tags                = var.tags

  name = each.key

  ingestion_access_mode = each.value.ingestion_access_mode
  query_access_mode     = each.value.query_access_mode
}

resource "azurerm_monitor_private_link_scoped_service" "this" {
  for_each = var.scoped_services

  resource_group_name = local.rg_name

  name = each.key

  scope_name = (
    each.value.scope != null
    ? azurerm_monitor_private_link_scope.this[each.value.scope].name
    : each.value.scope_name
  )

  linked_resource_id = each.value.linked_resource_id
}
