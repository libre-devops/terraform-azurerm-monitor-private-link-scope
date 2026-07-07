# Plan-time tests for the module. The azurerm provider is mocked, so no credentials, no
# features block, and no cloud calls are needed:
#   terraform init -backend=false && terraform test

mock_provider "azurerm" {}

variables {
  resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-ampls-01"
  tags              = { Environment = "tst" }

  private_link_scopes = {
    "ampls-ldo-uks-tst-001" = {}
  }

  scoped_services = {
    "scoped-law-central" = {
      scope              = "ampls-ldo-uks-tst-001"
      linked_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ldo-uks-tst-ampls-01/providers/Microsoft.OperationalInsights/workspaces/log-ldo-uks-tst-001"
    }
  }
}

run "renders_scope_and_scoped_service" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_private_link_scope.this) == 1 && length(azurerm_monitor_private_link_scoped_service.this) == 1
    error_message = "One scope and one scoped service should plan."
  }

  assert {
    condition     = azurerm_monitor_private_link_scope.this["ampls-ldo-uks-tst-001"].ingestion_access_mode == "Open" && azurerm_monitor_private_link_scope.this["ampls-ldo-uks-tst-001"].query_access_mode == "Open"
    error_message = "Access modes should default to Open."
  }

  assert {
    condition     = azurerm_monitor_private_link_scoped_service.this["scoped-law-central"].resource_group_name == "rg-ldo-uks-tst-ampls-01"
    error_message = "The resource group should parse from the id."
  }
}

run "private_only_modes_render" {
  command = plan

  variables {
    private_link_scopes = {
      "ampls-ldo-uks-tst-001" = {
        ingestion_access_mode = "PrivateOnly"
        query_access_mode     = "PrivateOnly"
      }
    }
  }

  assert {
    condition     = azurerm_monitor_private_link_scope.this["ampls-ldo-uks-tst-001"].ingestion_access_mode == "PrivateOnly"
    error_message = "PrivateOnly should render."
  }
}

run "warns_on_an_empty_scope" {
  command = plan

  variables {
    scoped_services = {}
  }

  expect_failures = [check.scopes_have_scoped_services]
}

run "rejects_a_bad_access_mode" {
  command = plan

  variables {
    private_link_scopes = {
      "ampls-bad" = { ingestion_access_mode = "Sometimes" }
    }
    scoped_services = {}
  }

  expect_failures = [var.private_link_scopes]
}

run "rejects_both_scope_key_and_name" {
  command = plan

  variables {
    scoped_services = {
      "scoped-bad" = {
        scope              = "ampls-ldo-uks-tst-001"
        scope_name         = "ampls-external"
        linked_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log-x"
      }
    }
  }

  expect_failures = [var.scoped_services]
}

run "rejects_an_unknown_scope_key" {
  command = plan

  variables {
    scoped_services = {
      "scoped-bad" = {
        scope              = "ampls-absent"
        linked_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log-x"
      }
    }
  }

  expect_failures = [var.scoped_services]
}
