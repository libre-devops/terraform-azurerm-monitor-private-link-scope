output "private_link_scope_ids" {
  description = "Map of scope name to id."
  value       = module.ampls.private_link_scope_ids
}

output "scoped_service_ids" {
  description = "Map of scoped service name to id."
  value       = module.ampls.scoped_service_ids
}
