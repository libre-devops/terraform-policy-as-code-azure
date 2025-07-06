package general.production_test

import rego.v1
import data.general.production as prod

# ---------------------------------------------------------------------------
# helper to build one resource-change entry
# ---------------------------------------------------------------------------
make(kind, addr, name) = {
  "address": addr,
  "type":    kind,
  "change":  { "after": { "name": name } },
}

# ---------------------------------------------------------------------------
# 1) All names are good  →  prod.deny must be empty
# ---------------------------------------------------------------------------
test_good_names_pass if {
  testInput := {
    "resource_changes": [
      make("azurerm_resource_group", "azurerm_resource_group.good", "rg-network"),
    ]
  }

  msgs := {m | prod.deny[m] with input as testInput}
  count(msgs) == 0                       # nothing denied
}

test_bad_name_fails if {
  testInput := {
    "resource_changes": [
      make("azurerm_resource_group", "azurerm_resource_group.bad", "network-rg"),
    ]
  }

  msgs := {m | prod.deny[m] with input as testInput}
  count(msgs) == 1                         # expect exactly one violation
}
