variable "private_link_scopes" {
  description = <<-EOT
    Map of Azure Monitor Private Link Scopes keyed by name (ampls-...). The access modes govern
    what happens to traffic arriving over a private endpoint into this scope: Open accepts
    telemetry from resources outside the scope too (the migration-friendly default),
    PrivateOnly hard-fails anything not scoped. Flip to PrivateOnly once every producer is a
    scoped service, or agents whose targets are missing go dark silently.
  EOT
  type = map(object({
    ingestion_access_mode = optional(string, "Open")
    query_access_mode     = optional(string, "Open")
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.private_link_scopes) :
      contains(["Open", "PrivateOnly"], s.ingestion_access_mode) && contains(["Open", "PrivateOnly"], s.query_access_mode)
    ])
    error_message = "ingestion_access_mode and query_access_mode must be Open or PrivateOnly."
  }
}

variable "resource_group_id" {
  description = "Id of the resource group to deploy into; the name is parsed from the id."
  type        = string
}

variable "scoped_services" {
  description = <<-EOT
    Map of scoped services keyed by name (purpose form, for example scoped-law-central): the
    Log Analytics workspaces, Application Insights components, and data collection endpoints
    whose telemetry rides the scope's private endpoint. linked_resource_id follows the pass-ids
    principle. Reference an in-module scope by map key (scope) or an existing one in the same
    resource group by name (scope_name); exactly one of the two.
  EOT
  type = map(object({
    scope      = optional(string)
    scope_name = optional(string)

    linked_resource_id = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.scoped_services) :
      length([for ref in [s.scope, s.scope_name] : ref if ref != null]) == 1
    ])
    error_message = "Each scoped service needs exactly one of scope (in-module key) or scope_name (existing scope in the same resource group)."
  }

  validation {
    condition = alltrue([
      for s in values(var.scoped_services) :
      s.scope == null || contains(keys(var.private_link_scopes), coalesce(s.scope, "-"))
    ])
    error_message = "scope must reference a key of private_link_scopes."
  }
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
