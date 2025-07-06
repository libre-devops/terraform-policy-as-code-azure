package terraform.plan_functions

import rego.v1

# Get resources by type
get_resources_by_type(type, resources) = filtered_resources if {
    filtered_resources := [resource | resource := resources[_]; resource.type = type]
}
