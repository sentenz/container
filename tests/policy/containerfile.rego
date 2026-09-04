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

final_user_indices := [index |
	some index
	command := input[index]
	command.Cmd == "user"
	command.Stage == final_stage
]

is_root_user(user) if {
	lower(user) == "root"
}

is_root_user(user) if {
	lower(user) == "0"
}

is_root_user(user) if {
	startswith(lower(user), "root:")
}

is_root_user(user) if {
	startswith(lower(user), "0:")
}

# METADATA
# title: Unprivileged runtime user
# description: Require the final image stage to select a non-root runtime user.
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
	is_root_user(user)

	msg := sprintf("The final image stage must not run as %q.", [user])
}
