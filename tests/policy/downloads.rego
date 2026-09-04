# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

is_shell_source if {
	is_object(input)
	input.kind == "ShellScript"
	is_string(input.path)
	is_string(input.content)
}

downloads_artifact(content) if {
	regex.match(`(?m)^[[:space:]]*curl[^\n]*(--output|-o)[[:space:]]`, content)
}

downloads_artifact(content) if {
	regex.match(`(?m)^[[:space:]]*wget[^\n]*(-O|--output-document)[=[:space:]]`, content)
}

downloads_sha256_manifest(content) if {
	regex.match(`(?im)^[[:space:]]*(curl|wget)[^\n]*(sha256(sum|sums)?|checksums?(\.txt)?)`, content)
}

computes_sha256(content) if {
	regex.match(`sha256sum[[:space:]]`, content)
}

checks_sha256(content) if {
	regex.match(`sha256sum[^\n]*(--check|-c)([[:space:]]|$)`, content)
}

checks_sha256(content) if {
	contains(content, "expected_checksum")
	contains(content, "actual_checksum")
	regex.match(`(?m)^[[:space:]]*if[[:space:]]+\[\[[^\n]*actual_checksum[^\n]*expected_checksum[^\n]*\]\]`, content)
	regex.match(`(?i)checksum mismatch`, content)
}

verifies_downloaded_artifact(content) if {
	downloads_sha256_manifest(content)
	computes_sha256(content)
	checks_sha256(content)
}

# METADATA
# title: Downloaded artifact verification
# description: Require downloaded artifacts to be checked against an upstream SHA-256 manifest.
# custom:
#   severity: high
# entrypoint: true
deny_download_verification contains msg if {
	is_shell_source
	downloads_artifact(input.content)
	not verifies_downloaded_artifact(input.content)

	msg := sprintf("Downloaded artifacts in %q must be verified against an upstream SHA-256 manifest.", [input.path])
}
