# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

shell_input(content) := {
	"kind": "ShellScript",
	"path": "containers/example/install.sh",
	"content": content,
}

test_download_accepts_independent_sha256_check if {
	candidate := shell_input(`
curl --output "${dir}/tool" -- "${url}/tool"
curl --output "${dir}/tool.sha256sum" -- "${url}/tool.sha256sum"
(
  cd -- "${dir}"
  sha256sum --check --status -- "tool.sha256sum"
)
`)
	result := deny_download_verification with input as candidate
	count(result) == 0
}

test_download_rejects_second_unverified_artifact if {
	candidate := shell_input(`
curl --output "${dir}/tool" -- "${url}/tool"
curl --output "${dir}/tool.sha256sum" -- "${url}/tool.sha256sum"
sha256sum --check -- "${dir}/tool.sha256sum"
curl --output "${dir}/other" -- "${url}/other"
`)
	result := deny_download_verification with input as candidate
	count(result) == 1
}

test_download_rejects_multiline_output if {
	candidate := shell_input(`
curl "${url}/tool" \
  --output "${dir}/tool"
`)
	result := deny_download_verification with input as candidate
	count(result) == 1
}

test_download_rejects_stdout_redirection if {
	candidate := shell_input(`
curl "${url}/tool" > "${dir}/tool"
`)
	result := deny_download_verification with input as candidate
	count(result) == 1
}

test_runtime_user_accepts_non_root_arg_default if {
	candidate := [
		{"Cmd": "from", "Stage": 0, "Value": ["scratch"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_GID=10001"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_UID=10001"]},
		{"Cmd": "user", "Stage": 0, "Value": ["${USER_UID}:${USER_GID}"]},
	]
	result := deny_runtime_user with input as candidate
	count(result) == 0
}

test_runtime_user_rejects_root_arg_default if {
	candidate := [
		{"Cmd": "from", "Stage": 0, "Value": ["scratch"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_GID=10001"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_UID=0"]},
		{"Cmd": "user", "Stage": 0, "Value": ["${USER_UID}:${USER_GID}"]},
	]
	result := deny_runtime_user with input as candidate
	count(result) == 1
}

test_runtime_user_rejects_unresolved_variable if {
	candidate := [
		{"Cmd": "from", "Stage": 0, "Value": ["scratch"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_GID=10001"]},
		{"Cmd": "user", "Stage": 0, "Value": ["${USER_UID}:${USER_GID}"]},
	]
	result := deny_runtime_user with input as candidate
	count(result) == 1
}

test_runtime_user_rejects_chained_arg_default if {
	candidate := [
		{"Cmd": "from", "Stage": 0, "Value": ["scratch"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["BASE_UID=0"]},
		{"Cmd": "arg", "Stage": 0, "Value": ["USER_UID=${BASE_UID}"]},
		{"Cmd": "user", "Stage": 0, "Value": ["${USER_UID}"]},
	]
	result := deny_runtime_user with input as candidate
	count(result) == 1
}

test_base_image_rejects_mutable_reference if {
	candidate := [
		{"Cmd": "from", "Stage": 0, "Value": ["alpine:3.24"]},
	]
	result := deny_base_image_pinning with input as candidate
	count(result) == 1
}

test_github_action_rejects_mutable_reference if {
	candidate := {
		"on": {"push": {}},
		"jobs": {
			"test": {
				"steps": [
					{"name": "Checkout", "uses": "actions/checkout@v7"},
				],
			},
		},
	}
	result := deny_github_action_pinning with input as candidate
	count(result) == 1
}

test_renovate_rejects_missing_manager_pin if {
	candidate := {
		"$schema": "https://docs.renovatebot.com/renovate-schema.json",
		"packageRules": [
			{"matchManagers": ["dockerfile"], "pinDigests": true},
		],
	}
	result := deny_renovate_pinning with input as candidate
	count(result) == 1
}
