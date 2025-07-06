package general.production

import rego.v1
import data.general.plan_functions
import input.resource_changes


################################################################################
#  **NEW**  Resource-Group rule
################################################################################
resource_groups := plan_functions.get_resources_by_type(
    "azurerm_resource_group",
    resource_changes,
)

check_rg_name(rg) if {
    startswith(rg.change.after.name, "rg-")
}

################################################################################
#  Generic helper – list the offenders for any predicate
################################################################################
bad(list, pred) = offenders {
    offenders := [x | x := list[_]; not pred(x)]
}

################################################################################
#  Single decision point used by the tests
################################################################################
deny[msg] {
    offenders := bad(linux_faps, check_fap_name) + bad(resource_groups, check_rg_name)

    offenders != []                                 # at least one offender

    msg := sprintf(
        "The following resource violates the naming convention: %s",
        [offenders[_].address],
    )
}
