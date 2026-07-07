output "private_link_scope_ids" {
  description = "Map of scope name to its id (the private endpoint's private_connection_resource_id, subresource azuremonitor). Carries the scoped services as a dependency: ARM allows one operation on the scope's dependent chain at a time, so a consumer's private endpoint must create after and destroy before the scoped services (AnotherOperationInProgress otherwise, caught live)."
  value       = { for k, v in azurerm_monitor_private_link_scope.this : k => v.id }

  depends_on = [azurerm_monitor_private_link_scoped_service.this]
}

output "private_link_scope_ids_zipmap" {
  description = "Map of scope name to {name, id} for easy composition. Carries the scoped services as a dependency, see private_link_scope_ids."
  value       = { for k, v in azurerm_monitor_private_link_scope.this : k => { name = v.name, id = v.id } }

  depends_on = [azurerm_monitor_private_link_scoped_service.this]
}

output "scoped_service_ids" {
  description = "Map of scoped service name to its id."
  value       = { for k, v in azurerm_monitor_private_link_scoped_service.this : k => v.id }
}
