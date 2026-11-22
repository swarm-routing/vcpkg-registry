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

.DEFAULT_GOAL := help
.PHONY: help build test lint format check clean shell ci headers org-sync-check org-tools dist

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

headers: org-tools ## licence headers (org rule 1)
	"$(ORG_DIR)/tools/checks/check-headers.sh" --dual '' --core '' .

check: lint test headers org-sync-check ## everything CI gates on

ci: check ## exactly what CI runs

# The release asset (swarm-routing/.github#636): the registry tree at HEAD as
# vcpkg-registry-<version>.tar.gz, deterministic (git archive). reusable-release.yml's
# build runs it at the release commit with RELEASE_VERSION set; locally it takes
# .cz.toml's version.
dist: ## the release asset: dist/vcpkg-registry-<version>.tar.gz
	@v="$${RELEASE_VERSION:-$$(python3 -I -c 'import tomllib; print(tomllib.load(open(".cz.toml", "rb"))["tool"]["commitizen"]["version"])')}" || exit $$?; \
	[ -n "$$v" ] || { echo "make dist: no version (RELEASE_VERSION or .cz.toml)" >&2; exit 1; }; \
	mkdir -p dist && git archive --format=tar.gz --prefix="vcpkg-registry-$$v/" -o "dist/vcpkg-registry-$$v.tar.gz" HEAD && \
	echo "dist/vcpkg-registry-$$v.tar.gz"

# org-sync:begin org-tools
# The org tooling (check-headers, org-sync): a shallow clone, refreshed to ORG_REF,
# by default the template commit .github/org-sync.lock pins, as CI checks (#586).
ORG_DIR   ?= $(HOME)/.cache/swarm-routing/dotgithub
ORG_REF   ?= $(or $(shell sed -nE 's/^commit = "([0-9a-f]{40})"[[:space:]]*$$/\1/p' .github/org-sync.lock 2>/dev/null),main)
# make pre-push TITLE='type(scope): subject': the PR title rule of reusable-pr-title.yml
export TITLE
TITLE_RE  := ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9._/-]+\))?!?: [^A-Z ](.*[^ ])?$$

.PHONY: org-tools org-sync-check pre-push

org-tools:  # the same templates CI checks against: refreshed to ORG_REF every time
	@[ -d "$(ORG_DIR)/.git" ] || { git init -q "$(ORG_DIR)" && git -C "$(ORG_DIR)" remote add origin https://github.com/swarm-routing/.github; }
	@git -C "$(ORG_DIR)" fetch -q --depth 1 origin $(ORG_REF) && git -C "$(ORG_DIR)" checkout -q --detach FETCH_HEAD

org-sync-check: org-tools ## org-managed files match the org templates
	python3 -I "$(ORG_DIR)/tools/org-sync/org_sync.py" check .

pre-push: check ## before every push: make check, then TITLE='type(scope): subject' (the PR title)
	@[ -n "$$TITLE" ] || { echo "make pre-push: pass TITLE='<the PR title>'" >&2; exit 2; }
	@printf '%s\n' "$$TITLE" | grep -Eq '$(TITLE_RE)' || { echo "PR title is not a lowercase Conventional Commit: $$TITLE" >&2; exit 1; }
	@echo "pre-push: ok ($$TITLE)"

.PHONY: doctor
doctor: ## this machine's tools against the versions CI runs (the org's tools/versions.env, go.mod), and the hosts the network steps need
	@$(MAKE) -s org-tools || echo "doctor: could not refresh $(ORG_DIR) (offline?): using it as it is" >&2
	@"$(ORG_DIR)/tools/doctor/doctor.sh" .
# org-sync:end org-tools
