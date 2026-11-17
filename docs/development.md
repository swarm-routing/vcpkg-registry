# Developer guide

This repository is the org's vcpkg git registry: one port per
simulator-free C++ core the org releases (`ports/swarm-core` today; the
protocol cores wait in `templates/` until their first release that installs
`core/` as a CMake package), the `versions/` database vcpkg reads, the
Python tool that renders a version bump, and a scratch consumer project CI
builds against every port. Most changes here are port bumps, which the org
bot opens after a release. This page shows how to set up, check, test a port
with vcpkg, and what CI runs. The rules are in [AGENTS.md](../AGENTS.md)
("Golden rules"); how to use the registry from a project is the README; how
issues and pull requests work is in the org's
[CONTRIBUTING.md](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md).

## Prerequisites

| Tool | Version | Needed for |
| --- | --- | --- |
| Linux or macOS, `git`, `make` | any recent | everything |
| Python | 3.11 or newer | `tools/port_bump.py` (standard library only) |
| ruff | 0.17.1 | Python lint and format |
| Docker with its daemon running, or Go | Docker: any recent; Go: 1.27 (swarm-routing/.github `go.mod`) | `make headers`: the licence gate CI runs, from the ci-tools image, or built with `go` when docker is absent |
| vcpkg | the commit `VCPKG_COMMIT` in `.github/workflows/registry.yml` | installing a port |
| CMake and Ninja, a C++23 compiler | CMake 3.20+, GCC 13 / Clang 17+ | the consumer build |
| emsdk | 4.0.10 (`EMSDK_VERSION` in `registry.yml`) | only the `wasm32-emscripten` triplet |
| Node.js | 18 or newer | only to run the WebAssembly consumer |

## Get the code

```bash
git clone https://github.com/swarm-routing/vcpkg-registry.git
cd vcpkg-registry
```

There are no submodules. vcpkg itself is a separate checkout at the pinned
commit (a partial clone is about 150 MB):

```bash
VCPKG_COMMIT=$(sed -n 's/^  VCPKG_COMMIT: //p' .github/workflows/registry.yml)
git clone --filter=blob:none --no-checkout https://github.com/microsoft/vcpkg.git ../vcpkg
git -C ../vcpkg checkout "$VCPKG_COMMIT" && ../vcpkg/bootstrap-vcpkg.sh -disableMetrics
```

## Dependencies

A port downloads the library's published release asset and checks its
SHA512; nothing is vendored. vcpkg's own helper ports (`vcpkg-cmake`,
`vcpkg-cmake-config`) come from vcpkg's builtin registry at `VCPKG_COMMIT`.
The org-wide move from release locks to this registry is
swarm-routing/.github#489; until then the org's own repositories consume
swarm-core by release lock (CONTRIBUTING "Dependencies"), and this registry
serves projects outside the org.

## Build

Nothing compiles in the repository itself (`make build` says so): ports are
data that vcpkg builds. A bump is rendered from a release:

```bash
python3 -I tools/port_bump.py bump --port swarm-core --tag vX.Y.Z   # SHA512 of the asset, git-tree, versions/
python3 -I tools/port_bump.py check                                 # versions/ matches ports/
```

`bump` computes the port's `git-tree` from the files as written, so no
commit is needed first, and `check` reads the working tree (run it before
committing). A library's first release copies its port from `templates/`
into `ports/` on its own. Between releases, `python3 -I tools/port_bump.py refresh
--port swarm-core` re-reads the port's description from its repository and
records a change as the next `port-version`.

## Test

| What | Command | CI |
| --- | --- | --- |
| the bump tool's self-test and the database check | `make test` | `tools` |
| the versions database against vcpkg | `../vcpkg/vcpkg x-ci-verify-versions --verbose --verify-git-trees --x-builtin-ports-root=./ports --x-builtin-registry-versions-dir=./versions` (see "Troubleshooting" for the one expected error) | `install (x64-linux)` |
| every port installs and a `find_package` consumer builds and runs | the consumer build below | `install (x64-linux)`, `install (wasm32-emscripten)` |

The consumer, as `registry.yml` builds it (run from this checkout, with the
port change committed, since vcpkg reads a git registry from commits):

```bash
work=$(mktemp -d)/consumer && cp -r test/consumer "$work"
cat > "$work/vcpkg-configuration.json" <<EOF
{ "default-registry": { "kind": "builtin", "baseline": "$VCPKG_COMMIT" },
  "registries": [ { "kind": "git", "repository": "$PWD", "reference": "HEAD",
                    "baseline": "$(git rev-parse HEAD)", "packages": ["swarm-core"] } ] }
EOF
VCPKG_ROOT=$PWD/../vcpkg
cmake -S "$work" -B "$work/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET=x64-linux
cmake --build "$work/build" && "$work/build/consumer"
```

`x64-linux` is CI's triplet. On macOS pick the native one instead,
`-DVCPKG_TARGET_TRIPLET=arm64-osx` on Apple silicon or `x64-osx` on Intel,
and the consumer runs the same way. CI lists every directory under `ports/`
in `packages` and in the consumer's `vcpkg.json`; with one port that is
`swarm-core`. For
WebAssembly, activate emsdk, use `-DVCPKG_TARGET_TRIPLET=wasm32-emscripten
-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"`
and run `node "$work/build/consumer.js"`.

## Run

There is nothing to run here beyond the consumer above. Using a port from
your own project (the `vcpkg-configuration.json` with this registry, the
`vcpkg.json` dependency, `find_package(swarm-core CONFIG REQUIRED)`) is the
README's "Use the registry".

## Docker and dev containers

Nothing here needs Docker; `make shell` opens a shell in the org's
`ns3-dev` image with this checkout at `/src`, which has CMake, Ninja and GCC
but not vcpkg. There is no `.devcontainer/`.

## Lint and format

```bash
make lint      # ruff check + ruff format --check on tools/
make format    # ruff format
make headers   # licence headers (fetches the org tools)
make org-sync-check
make check     # lint, test, headers and org-sync together (everything CI gates on except vcpkg)
```

## CI map

| Workflow | Job (check name) | What it checks | Required |
| --- | --- | --- | --- |
| `registry.yml` | `tools` | `port_bump.py` self-test and check, ruff | yes |
| `registry.yml` | `install (x64-linux)` | the versions database (`x-ci-verify-versions`), every port installs, the consumer builds and runs | yes |
| `registry.yml` | `install (wasm32-emscripten)` | the same on WebAssembly, the consumer run with Node | yes |
| `licence.yml` | `headers / licence` | licence headers | yes |
| `org-sync.yml` | `check / org-sync` | the org-managed files match the templates | yes |
| `pr-title.yml` | `title / title` | the PR title is a lowercase Conventional Commit | yes |
| `review-gate.yml` | `review / coderabbit` | the review gate: passes once CodeRabbit has reviewed the PR or said it will not, for a draft, or 30 minutes after the PR opened; a pass is not proof of a review, so read the threads | yes |
| `dco.yml`, `scorecard.yml`, `sync-labels.yml` | | sign-off on outside contributions; OpenSSF Scorecard; labels | no |

The required checks are the ones the `main` ruleset lists: `gh api
repos/swarm-routing/vcpkg-registry/rules/branches/main`. `main` merges
through a merge queue, so a pull request is merged by enabling auto-merge;
the org bot's bump PRs (`bot/vcpkg-<repository>`) arrive with auto-merge on.

## Release

Consumers pin a commit of `main` as their `baseline`; vcpkg never reads a
tag. The registry itself also carries versioned releases
(swarm-routing/.github#636), cut on the maintainer's request only:
`.github/workflows/release.yml` calls swarm-routing/.github's
`reusable-release.yml` (dispatch `dry-run`, then `bump`; merging the bot's
`chore(release): bump version A to B` PR tags `vX.Y.Z` and publishes
`vcpkg-registry-X.Y.Z.tar.gz`, the tree at that commit, written by `make
dist`), with `.cz.toml` (Commitizen) and `CITATION.cff`. The ladder is
[`docs/roadmap.md`](roadmap.md). A tag names a commit a consumer may use as
its baseline. A new port version arrives when its library releases: the
library's release job runs `port_bump.py bump` and the org bot opens the PR
here (CONTRIBUTING "Outside the org: the vcpkg registry"). How the libraries
themselves release is [CONTRIBUTING "Cutting a release"](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#cutting-a-release).
A protocol core's port moves from `templates/` to `ports/` with its first
release that installs `core/` as a CMake package.

## Troubleshooting

- **`x-ci-verify-versions` reports `vcpkg-cmake` or `vcpkg-cmake-config`
  missing from the version database.** Expected: they are vcpkg's builtin
  helpers, not ours, and CI accepts exactly that error. Filter it with
  `| grep ': error:' | grep -Ev 'error: the dependency vcpkg-cmake(-config)? does not exist in the version database'`.
  A pass is empty output from that filter *and* at least one line saying a
  port `is correctly in the version database` in the unfiltered output, as
  CI requires: a run that verified no port also prints no error.
- **`check` or vcpkg says a `git-tree` does not match.** A port's files
  changed after its version was recorded. If the change was not meant,
  revert it. A deliberate change at the same version needs a new
  `port-version`, which `port_bump.py` records only for a changed
  description (`refresh`); `bump` refuses another tree for a recorded
  version. Any other such change needs an issue first; never edit a hash by
  hand.
- **The consumer resolves an old port version.** The registry's `baseline`
  is a commit; the change must be committed and the baseline must be that
  commit (`git rev-parse HEAD`).
- **The SHA512 does not match on install.** The release asset changed or the
  tag is wrong; render the bump from the release again, never type a hash.
- **The WebAssembly build cannot find `emcc`.** Activate emsdk 4.0.10 first
  (`source <emsdk>/emsdk_env.sh`).
