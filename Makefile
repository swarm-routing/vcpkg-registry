# Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing)
# SPDX-License-Identifier: MIT OR GPL-2.0-only
#
# vcpkg-registry: the org's standard targets (swarm-routing/.github#11). Every org
# repo has these same target names, with this repo's own commands behind them;
# `org-sync check` verifies the names are present, never the recipes. Add
# repo-only targets at the end. `make help` lists everything with a `## ` note.

NS3_IMAGE ?= ghcr.io/swarm-routing/ns3-dev:latest-debug
PLATFORM  ?=
# container kind: the image's Dockerfile and its build arguments
DOCKERFILE ?= Dockerfile
BUILD_ARGS ?=
# The org tooling (check-headers.py, org-sync): a shallow clone, refreshed to ORG_REF.
ORG_DIR   ?= $(HOME)/.cache/swarm-routing/dotgithub
ORG_REF   ?= main

.DEFAULT_GOAL := help
.PHONY: help build test lint format check clean shell ci headers org-sync-check org-tools

help: ## list the targets
	@awk 'BEGIN{FS=":.*## "} /^[a-zA-Z0-9_-]+:.*## /{printf "  %-16s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## build what this repo ships (nothing: ports are data, built by vcpkg)
	@echo "nothing to build: run vcpkg install (README)"

test: ## the fast tests CI runs on every PR
	@if [ -f tools/port_bump.py ]; then python3 -I tools/port_bump.py --self-test && python3 -I tools/port_bump.py check; else echo "no tests yet"; fi

lint: ## static checks, no changes
	@if [ -d tools ]; then ruff check tools && ruff format --check tools; else echo "no tools/ yet"; fi

format: ## apply the formatters
	@if [ -d tools ]; then ruff format tools; else echo "no tools/ yet"; fi

clean: ## remove build outputs
	rm -rf build dist *.egg-info .pytest_cache

shell: ## an interactive shell in the dev image with this repo at /src
	@command -v docker >/dev/null || { echo "make shell: docker not found (Docker Desktop, Colima, or docker.io)" >&2; exit 127; }
	docker run --rm -it -v "$(CURDIR):/src" -w /src $(if $(PLATFORM),--platform $(PLATFORM)) $(NS3_IMAGE) bash

org-tools:  # the same templates CI checks against: refreshed to ORG_REF every time
	@[ -d "$(ORG_DIR)/.git" ] || { git init -q "$(ORG_DIR)" && git -C "$(ORG_DIR)" remote add origin https://github.com/swarm-routing/.github; }
	@git -C "$(ORG_DIR)" fetch -q --depth 1 origin $(ORG_REF) && git -C "$(ORG_DIR)" checkout -q --detach FETCH_HEAD

headers: org-tools ## licence headers (org rule 1)
	python3 -I "$(ORG_DIR)/tools/checks/check-headers.py" --dual '' --core '' .

org-sync-check: org-tools ## org-managed files match the org templates
	python3 -I "$(ORG_DIR)/tools/org-sync/org_sync.py" check .

check: lint test headers org-sync-check ## everything CI gates on

ci: check ## exactly what CI runs
