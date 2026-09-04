# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

required_pin_managers := {"dockerfile", "github-actions"}

is_renovate_config if {
	is_object(input)
	startswith(object.get(input, "$schema", ""), "https://docs.renovatebot.com/")
}

manager_pins_digests(manager) if {
	some rule in object.get(input, "packageRules", [])
	some configured_manager in object.get(rule, "matchManagers", [])
	configured_manager == manager
	object.get(rule, "pinDigests", false) == true
}

# METADATA
# title: Renovate immutable pin preservation
# description: Require Renovate to preserve digest pins for container images and GitHub Actions.
# custom:
#   severity: high
# entrypoint: true
deny_renovate_pinning contains msg if {
	is_renovate_config

	some manager in required_pin_managers
	not manager_pins_digests(manager)

	msg := sprintf("Renovate manager %q must set pinDigests to true.", [manager])
}
