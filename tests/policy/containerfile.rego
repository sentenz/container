# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

is_containerfile if {
	is_array(input)
	count(input) > 0
	object.get(input[0], "Cmd", "") != ""
}

stage_aliases contains lower(alias) if {
	is_containerfile

	some command in input
	command.Cmd == "from"
	count(command.Value) >= 3
	lower(command.Value[1]) == "as"
	alias := command.Value[2]
}

is_internal_stage(image) if {
	lower(image) in stage_aliases
}

is_immutable_image(image) if {
	regex.match(`^[^@[:space:]]+@sha256:[0-9a-f]{64}$`, lower(image))
}

# METADATA
# title: Container base image pinning
# description: Require external base images to use an immutable SHA-256 digest.
# custom:
#   severity: high
# entrypoint: true
deny_base_image_pinning contains msg if {
	is_containerfile

	some command in input
	command.Cmd == "from"
	image := command.Value[0]
	lower(image) != "scratch"
	not is_internal_stage(image)
	not is_immutable_image(image)

	msg := sprintf("Container base image %q must be pinned to a full sha256 digest.", [image])
}

final_stage := max([command.Stage | some command in input]) if {
	is_containerfile
}

final_stage_from_index := min([index |
	some index
	command := input[index]
	command.Cmd == "from"
	command.Stage == final_stage
]) if {
	is_containerfile
}

final_user_indices := [index |
	some index
	command := input[index]
	command.Cmd == "user"
	command.Stage == final_stage
]

user_variable_name(value) := trim_suffix(trim_prefix(value, "${"), "}") if {
	regex.match(`^\$\{[A-Za-z_][A-Za-z0-9_]*\}$`, value)
}

user_variable_name(value) := trim_prefix(value, "$") if {
	regex.match(`^\$[A-Za-z_][A-Za-z0-9_]*$`, value)
}

arg_default(name, before_index) := value if {
	prefix := sprintf("%s=", [name])
	indices := [index |
		some index
		command := input[index]
		command.Cmd == "arg"
		command.Stage == final_stage
		index > final_stage_from_index
		index < before_index
		some argument in command.Value
		startswith(argument, prefix)
	]
	count(indices) > 0

	latest_index := max(indices)
	some argument in input[latest_index].Value
	startswith(argument, prefix)
	value := trim(trim_prefix(argument, prefix), `"'`)
}

resolved_user_identity(user, user_index) := identity if {
	identity := split(user, ":")[0]
	not contains(identity, "$")
}

resolved_user_identity(user, user_index) := value if {
	identity := split(user, ":")[0]
	name := user_variable_name(identity)
	value := arg_default(name, user_index)
	value != ""
	not contains(value, "$")
}

has_resolved_user_identity(user, user_index) if {
	resolved_user_identity(user, user_index) != ""
}

is_root_user(user) if {
	lower(user) == "root"
}

is_root_user(user) if {
	regex.match(`^0+$`, user)
}

# METADATA
# title: Unprivileged runtime user
# description: Require the final image stage to select a provably non-root runtime user.
# custom:
#   severity: high
# entrypoint: true
deny_runtime_user contains msg if {
	is_containerfile
	count(final_user_indices) == 0

	msg := "The final image stage must select an unprivileged user with USER."
}

deny_runtime_user contains msg if {
	is_containerfile
	count(final_user_indices) > 0
	last_user_index := max(final_user_indices)
	user := input[last_user_index].Value[0]
	identity := split(user, ":")[0]
	contains(identity, "$")
	not has_resolved_user_identity(user, last_user_index)

	msg := sprintf("The final image stage user %q must resolve from a preceding ARG default.", [user])
}

deny_runtime_user contains msg if {
	is_containerfile
	count(final_user_indices) > 0
	last_user_index := max(final_user_indices)
	user := input[last_user_index].Value[0]
	identity := resolved_user_identity(user, last_user_index)
	is_root_user(identity)

	msg := sprintf("The final image stage must not run as %q.", [user])
}
