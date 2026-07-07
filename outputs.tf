output "private_link_scope_ids" {
  description = "Map of scope name to its id (the private endpoint's private_connection_resource_id, subresource azuremonitor)."
  value       = { for k, v in azurerm_monitor_private_link_scope.this : k => v.id }
}

output "private_link_scope_ids_zipmap" {
  description = "Map of scope name to {name, id} for easy composition."
  value       = { for k, v in azurerm_monitor_private_link_scope.this : k => { name = v.name, id = v.id } }
}

output "scoped_service_ids" {
  description = "Map of scoped service name to its id."
  value       = { for k, v in azurerm_monitor_private_link_scoped_service.this : k => v.id }
}
