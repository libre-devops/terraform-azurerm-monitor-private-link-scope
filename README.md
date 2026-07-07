<!--
  Keep the title and badges OUTSIDE the centered <div>: the Terraform Registry's markdown renderer
  does not parse markdown inside an HTML block, so a # heading or [![badge]] in the div renders as
  literal text on the registry. Only the logo (HTML) goes in the div.
-->
<div align="center">
  <a href="https://libredevops.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://libredevops.org/assets/libre-devops-white.png">
      <img alt="Libre DevOps" src="https://libredevops.org/assets/libre-devops-black.png" width="300">
    </picture>
  </a>
</div>

# Terraform Azure Monitor Private Link Scope

Azure Monitor Private Link Scopes (AMPLS) and scoped services: the private path for telemetry
ingestion and queries.

[![CI](https://github.com/libre-devops/terraform-azurerm-monitor-private-link-scope/actions/workflows/ci.yml/badge.svg)](https://github.com/libre-devops/terraform-azurerm-monitor-private-link-scope/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/libre-devops/terraform-azurerm-monitor-private-link-scope?sort=semver&label=release)](https://github.com/libre-devops/terraform-azurerm-monitor-private-link-scope/releases/latest)
[![Terraform Registry](https://img.shields.io/badge/registry-libre--devops-7B42BC?logo=terraform&logoColor=white)](https://registry.terraform.io/namespaces/libre-devops)
[![License](https://img.shields.io/github/license/libre-devops/terraform-azurerm-monitor-private-link-scope)](./LICENSE)

---

## Overview

Azure Monitor's endpoints are shared and public by default; an AMPLS is the one mechanism that
gives workspaces, Application Insights components, and data collection endpoints a private
ingestion and query path through a single private endpoint. Small family, sharp edges:

- **Scopes as a typed map** (ampls-...), with the two access modes explicit and validated.
  They default to Open on purpose: PrivateOnly hard-fails any producer that is not a scoped
  service, so agents pointing at an unscoped target go dark silently. The variable documents
  the migration order (scope everything, then flip).
- **Scoped services by pass-ids**: linked_resource_id takes the workspace, component, or DCE
  id; the scope is referenced by in-module key or by name for an existing scope. A check
  surfaces scopes with no scoped services, which guard nothing (and blackhole when
  PrivateOnly).
- **The composition is the point**: one private endpoint onto the scope (subresource
  azuremonitor) fans out to every scoped service, resolved through the five privatelink
  monitor zones. The complete example wires all of it with the private-dns-zone and
  private-endpoint modules, scoping a workspace, a component, and a data collection endpoint.

AMPLS is global (regionless); the scope id output is exactly what the private endpoint's
connection takes.

<!-- BEGIN_TF_DOCS -->
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

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_monitor_private_link_scope.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scope) | resource |
| [azurerm_monitor_private_link_scoped_service.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_private_link_scoped_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_private_link_scopes"></a> [private\_link\_scopes](#input\_private\_link\_scopes) | Map of Azure Monitor Private Link Scopes keyed by name (ampls-...). The access modes govern<br/>what happens to traffic arriving over a private endpoint into this scope: Open accepts<br/>telemetry from resources outside the scope too (the migration-friendly default),<br/>PrivateOnly hard-fails anything not scoped. Flip to PrivateOnly once every producer is a<br/>scoped service, or agents whose targets are missing go dark silently. | <pre>map(object({<br/>    ingestion_access_mode = optional(string, "Open")<br/>    query_access_mode     = optional(string, "Open")<br/>  }))</pre> | `{}` | no |
| <a name="input_resource_group_id"></a> [resource\_group\_id](#input\_resource\_group\_id) | Id of the resource group to deploy into; the name is parsed from the id. | `string` | n/a | yes |
| <a name="input_scoped_services"></a> [scoped\_services](#input\_scoped\_services) | Map of scoped services keyed by name (purpose form, for example scoped-law-central): the<br/>Log Analytics workspaces, Application Insights components, and data collection endpoints<br/>whose telemetry rides the scope's private endpoint. linked\_resource\_id follows the pass-ids<br/>principle. Reference an in-module scope by map key (scope) or an existing one in the same<br/>resource group by name (scope\_name); exactly one of the two. | <pre>map(object({<br/>    scope      = optional(string)<br/>    scope_name = optional(string)<br/><br/>    linked_resource_id = string<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_private_link_scope_ids"></a> [private\_link\_scope\_ids](#output\_private\_link\_scope\_ids) | Map of scope name to its id (the private endpoint's private\_connection\_resource\_id, subresource azuremonitor). |
| <a name="output_private_link_scope_ids_zipmap"></a> [private\_link\_scope\_ids\_zipmap](#output\_private\_link\_scope\_ids\_zipmap) | Map of scope name to {name, id} for easy composition. |
| <a name="output_scoped_service_ids"></a> [scoped\_service\_ids](#output\_scoped\_service\_ids) | Map of scoped service name to its id. |
<!-- END_TF_DOCS -->
