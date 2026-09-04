# SPDX-License-Identifier: Apache-2.0

SHELL := bash
.SHELLFLAGS := -euo pipefail -c

CONTAINER_ENGINE ?= docker
CONTAINER_REGISTRY ?= ghcr.io/sentenz
CONTAINER_TAG ?= dev
CONFTEST ?= conftest

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

## Validate the supply-chain policy with Conftest
policy:
	@./scripts/policy-inputs
	@$(CONFTEST) test .
.PHONY: policy

## Build every catalog image
build:
	@./scripts/container build
.PHONY: build

## Build one image, for example make build-k8s
build-%:
	@./scripts/container build "$*"
.PHONY: build-%
