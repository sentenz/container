# SPDX-License-Identifier: Apache-2.0

package tests.policy

import rego.v1

is_shell_source if {
	is_object(input)
	input.kind == "ShellScript"
	is_string(input.path)
	is_string(input.content)
}

normalized_shell(content) := regex.replace(content, `\\[ \t]*\n`, " ")

shell_lines(content) := [trim_space(line) |
	some line in split(normalized_shell(content), "\n")
	trim_space(line) != ""
]

is_curl_command(line) if {
	regex.match(`(^|[[:space:]])curl[[:space:]]`, line)
}

is_wget_command(line) if {
	regex.match(`(^|[[:space:]])wget[[:space:]]`, line)
}

is_download_command(line) if {
	is_curl_command(line)
}

is_download_command(line) if {
	is_wget_command(line)
}

has_explicit_output(line) if {
	is_curl_command(line)
	regex.match(`(--output|-o)[[:space:]]+`, line)
}

has_explicit_output(line) if {
	is_wget_command(line)
	regex.match(`(-O|--output-document)(=|[[:space:]]+)`, line)
}

download_targets contains target if {
	is_shell_source
	some line in shell_lines(input.content)
	is_curl_command(line)
	some match in regex.find_all_string_submatch_n(`(--output|-o)[[:space:]]+("[^"]+"|'[^']+'|[^[:space:]]+)`, line, -1)
	target := trim(match[2], `"'`)
}

download_targets contains target if {
	is_shell_source
	some line in shell_lines(input.content)
	is_wget_command(line)
	some match in regex.find_all_string_submatch_n(`(-O|--output-document)(=|[[:space:]]+)("[^"]+"|'[^']+'|[^[:space:]]+)`, line, -1)
	target := trim(match[3], `"'`)
}

download_targets contains target if {
	is_shell_source
	some line in shell_lines(input.content)
	is_download_command(line)
	not has_explicit_output(line)
	some match in regex.find_all_string_submatch_n(`(^|[[:space:]])>[[:space:]]*("[^"]+"|'[^']+'|[^[:space:]]+)`, line, -1)
	target := trim(match[2], `"'`)
}

is_checksum_manifest(target) if {
	regex.match(`(?i)\.(sha256|sha256sum|sha256sums)$`, target)
}

is_checksum_manifest_for(target, manifest) if {
	manifest == sprintf("%s.sha256", [target])
}

is_checksum_manifest_for(target, manifest) if {
	manifest == sprintf("%s.sha256sum", [target])
}

is_checksum_manifest_for(target, manifest) if {
	manifest == sprintf("%s.sha256sums", [target])
}

path_basename(path) := parts[count(parts) - 1] if {
	parts := split(path, "/")
	count(parts) > 0
}

is_sha256_check_command(line) if {
	regex.match(`(^|[[:space:]])sha256sum[[:space:]]`, line)
	regex.match(`(^|[[:space:]])(--check|-c)([=[:space:]]|$)`, line)
}

line_references_manifest(line, manifest) if {
	contains(line, manifest)
}

line_references_manifest(line, manifest) if {
	contains(line, path_basename(manifest))
}

checks_manifest(manifest) if {
	some line in shell_lines(input.content)
	is_sha256_check_command(line)
	line_references_manifest(line, manifest)
}

verifies_download(target) if {
	some manifest in download_targets
	is_checksum_manifest_for(target, manifest)
	checks_manifest(manifest)
}

# METADATA
# title: Downloaded artifact verification
# description: Require every downloaded artifact to be checked against its own upstream SHA-256 manifest.
# custom:
#   severity: high
# entrypoint: true
deny_download_verification contains msg if {
	is_shell_source
	some target in download_targets
	not is_checksum_manifest(target)
	not verifies_download(target)

	msg := sprintf("Downloaded artifact %q in %q must be verified against its own upstream SHA-256 manifest.", [target, input.path])
}
