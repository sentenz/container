#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0

set -Eeuo pipefail
umask 022

: "${KIND_VERSION:?KIND_VERSION is required}"
: "${TARGETOS:=linux}"
: "${TARGETARCH:?TARGETARCH is required}"
: "${INSTALL_DIR:=/usr/local/bin}"

case "${TARGETOS}" in
  linux) os=linux ;;
  *)
    printf 'install-kind: unsupported operating system: %s\n' "${TARGETOS}" >&2
    exit 1
    ;;
esac

case "${TARGETARCH}" in
  amd64 | x86_64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *)
    printf 'install-kind: unsupported architecture: %s\n' "${TARGETARCH}" >&2
    exit 1
    ;;
esac

if [[ ! "${KIND_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  printf 'install-kind: invalid version: %s\n' "${KIND_VERSION}" >&2
  exit 1
fi

readonly asset="kind-${os}-${arch}"
readonly base_url="https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}"
temporary_directory="$(mktemp -d)"
readonly temporary_directory

cleanup() {
  rm -rf -- "${temporary_directory}"
}
trap cleanup EXIT INT TERM HUP

readonly curl_options=(
  --connect-timeout 15
  --fail
  --location
  --proto '=https'
  --proto-redir '=https'
  --retry 5
  --retry-all-errors
  --retry-delay 2
  --show-error
  --silent
  --tlsv1.2
)

curl "${curl_options[@]}" --output "${temporary_directory}/${asset}" -- "${base_url}/${asset}"
curl "${curl_options[@]}" --output "${temporary_directory}/${asset}.sha256sum" -- "${base_url}/${asset}.sha256sum"

expected_checksum="$(
  awk -v expected_name="${asset}" \
    '$2 == expected_name || $2 == "*" expected_name {print $1; exit}' \
    "${temporary_directory}/${asset}.sha256sum"
)"
readonly expected_checksum

if [[ ! "${expected_checksum}" =~ ^[0-9A-Fa-f]{64}$ ]]; then
  printf 'install-kind: invalid checksum manifest for %s\n' "${asset}" >&2
  exit 1
fi

actual_checksum="$(sha256sum "${temporary_directory}/${asset}" | awk '{print $1}')"
readonly actual_checksum

if [[ "${actual_checksum,,}" != "${expected_checksum,,}" ]]; then
  printf 'install-kind: checksum mismatch for %s\n' "${asset}" >&2
  exit 1
fi

install -d -m 0755 -- "${INSTALL_DIR}"
install -m 0755 -- "${temporary_directory}/${asset}" "${INSTALL_DIR}/kind"
