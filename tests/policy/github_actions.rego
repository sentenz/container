# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

is_github_workflow if {
	is_object(input)
	is_object(object.get(input, "jobs", null))
	object.get(input, "on", "__missing__") != "__missing__"
}

# Conftest's YAML parser currently interprets the YAML 1.1 key `on` as `true`.
is_github_workflow if {
	is_object(input)
	is_object(object.get(input, "jobs", null))
	object.get(input, "true", "__missing__") != "__missing__"
}

is_local_action(reference) if {
	startswith(reference, "./")
}

is_immutable_action(reference) if {
	regex.match(`^[^@[:space:]]+@[0-9a-f]{40}$`, lower(reference))
}

is_immutable_action(reference) if {
	regex.match(`^docker://[^@[:space:]]+@sha256:[0-9a-f]{64}$`, lower(reference))
}

# METADATA
# title: Immutable GitHub Action reference
# description: Require external actions and reusable workflows to use commit SHAs.
# custom:
#   severity: high
# entrypoint: true
deny_github_action_pinning contains msg if {
	is_github_workflow

	some job_name, job in input.jobs
	some step_index, step in object.get(job, "steps", [])
	reference := object.get(step, "uses", "")
	reference != ""
	not is_local_action(reference)
	not is_immutable_action(reference)
	step_name := object.get(step, "name", sprintf("step %d", [step_index + 1]))

	msg := sprintf("GitHub Action %q in job %q, step %q must use a full commit SHA.", [reference, job_name, step_name])
}

deny_github_action_pinning contains msg if {
	is_github_workflow

	some job_name, job in input.jobs
	reference := object.get(job, "uses", "")
	reference != ""
	not is_local_action(reference)
	not is_immutable_action(reference)

	msg := sprintf("Reusable workflow %q in job %q must use a full commit SHA.", [reference, job_name])
}
