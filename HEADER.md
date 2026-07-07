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
