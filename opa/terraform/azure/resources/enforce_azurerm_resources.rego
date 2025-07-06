package terraform.azure.only_rg

###############################################################################
# Helper: the set of resource-changes that are allowed
###############################################################################
allowed contains rc if {                       # ← `contains` rule
  rc := input.resource_changes[_]              # bind rc inside the rule
  rc.type == "azurerm_resource_group"
  rc.change.actions == ["create"]              # exactly ["create"]
}

###############################################################################
# Policy: add a message to deny[] for every change NOT in allowed
###############################################################################
deny contains msg if {
  rc := input.resource_changes[_]

  not rc in allowed                            # membership test for sets

  msg := sprintf("deny:%s:%s", [rc.type, rc.name])
}
