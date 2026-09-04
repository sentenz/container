# SPDX-License-Identifier: Apache-2.0

SHELL := bash
.SHELLFLAGS := -euo pipefail -c

CONTAINER_ENGINE ?= docker
CONTAINER_REGISTRY ?= ghcr.io/sentenz
CONTAINER_TAG ?= dev

POLICY_CONFTEST_IMAGE ?= docker.io/openpolicyagent/conftest:v0.69.0@sha256:a38ba21668929a00dce2fe6ee43d1312228340bce5fd243f47dd0ce90516e558
POLICY_CONFTEST_ALIAS := docker run --rm --volume "$(CURDIR):/workspace" --workdir /workspace "$(POLICY_CONFTEST_IMAGE)"

export CONTAINER_ENGINE
export CONTAINER_REGISTRY
export CONTAINER_TAG

.DEFAULT_GOAL := help

## Display available targets
help:
	@awk 'BEGIN {printf "Targets:\n"} /^## / {description = substr($$0, 4); next} /^[a-zA-Z0-9_%-]+:/ && description {target = $$1; sub(/:$$/, "", target); printf "  %-20s %s\n", target, description; description = ""}' $(MAKEFILE_LIST)
.PHONY: help

## List catalog images
list:
	@./scripts/container list
.PHONY: list

## Validate the image catalog and directory layout
validate:
	@./scripts/container validate
.PHONY: validate

## Validate the supply-chain policy with Conftest and generate a report
policy:
	@./scripts/policy-inputs
	@mkdir -p logs/policy
	@$(POLICY_CONFTEST_ALIAS) test . 2>&1 | tee logs/policy/conftest-report.json
.PHONY: policy

## Build every catalog image
build:
	@./scripts/container build
.PHONY: build

## Build one image, for example make build-k8s
build-%:
	@./scripts/container build "$*"
.PHONY: build-%
