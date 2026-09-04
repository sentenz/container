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
