# vcpkg-registry

<!-- org-sync:begin badges -->
| Group | Badges |
| --- | --- |
| Release | [![Licence: MIT OR GPL-2.0-only](https://img.shields.io/badge/licence-MIT%20OR%20GPL--2.0--only-blue)](LICENSING.md) |
| Trust | [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/swarm-routing/vcpkg-registry/badge)](https://scorecard.dev/viewer/?uri=github.com/swarm-routing/vcpkg-registry) |
| Stack | [![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue?logo=python)](AGENTS.md) |
| Community & docs | [![Open RCAPA](https://img.shields.io/github/issues/swarm-routing/vcpkg-registry/rcapa?label=open%20RCAPA&color=blue)](https://github.com/swarm-routing/vcpkg-registry/blob/main/docs/rcapa/README.md) [![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)](https://www.conventionalcommits.org) |
<!-- org-sync:end badges -->

The swarm-routing org's [vcpkg git registry](https://learn.microsoft.com/vcpkg/maintainers/registries)
for the simulator-free C++ cores it releases. Each port builds a published
release asset, checked by its SHA512, and installs the library as a CMake
package. CI installs every port on `x64-linux` and `wasm32-emscripten` and
builds a `find_package` consumer (epic swarm-routing/.github#436).

| Port | Version | Library | Package and target | Source |
|------|---------|---------|--------------------|--------|
| `swarm-core` | [![vcpkg: swarm-core](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fswarm-routing%2Fvcpkg-registry%2Fmain%2Fports%2Fswarm-core%2Fvcpkg.json&query=%24%5B%22version-semver%22%5D&label=vcpkg%20swarm-core)](ports/swarm-core) | the shared swarm-routing primitives (`core/` of [ns3-swarm-core](https://github.com/swarm-routing/ns3-swarm-core)), C++23 (since 0.4.0) | `find_package(swarm-core CONFIG REQUIRED)`, `swarm::core` | `swarm-core-<ver>.tar.gz` of each release |

Each port's description is its upstream repository's GitHub description
(declared as code there), written by `tools/port_bump.py` at every bump
(`refresh` re-reads it between releases), so it cannot go stale.

The protocol cores follow, each on the `swarm-core` port: their ports wait
in `templates/` and move into `ports/` by themselves on the first release of
each repository that installs `core/` as a CMake package (epic
swarm-routing/.github#436):

| Template | Package and target | Waits for |
|----------|--------------------|-----------|
| `ara-core` | `find_package(ara-core CONFIG REQUIRED)`, `ara::core` | swarm-routing/ARA#167, then an ARA release |
| `beeadhoc-core` | `beeadhoc-core`, `beeadhoc::core` | swarm-routing/BeeAdHoc#142, then a release |
| `termite-core` | `termite-core`, `termite::core` | swarm-routing/Termite#135, then a release |
| `hopnet-core` | `hopnet-core`, `hopnet::core` | swarm-routing/HOPNET#143, then a release |
| `anthocnet-core` | `anthocnet-core`, `anthocnet::core` | swarm-routing/AntHocNet#1037, then a release (its `anthocnet-<ver>.zip`, checked against `<asset>.sha256`) |

## Use the registry

Add it next to vcpkg's own registry in your project's
`vcpkg-configuration.json` (`baseline`: a commit of this repository's `main`,
which fixes the versions you get until you move it):

```json
{
  "default-registry": {
    "kind": "git",
    "repository": "https://github.com/microsoft/vcpkg",
    "baseline": "<a microsoft/vcpkg commit>"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/swarm-routing/vcpkg-registry",
      "baseline": "<a commit of this repository's main>",
      "packages": ["swarm-core"]
    }
  ]
}
```

and depend on the port in `vcpkg.json`:

```json
{
  "dependencies": ["swarm-core"],
  "overrides": [{ "name": "swarm-core", "version": "0.4.0" }]
}
```

Then, with the vcpkg toolchain file:

```cmake
find_package(swarm-core CONFIG REQUIRED)
target_link_libraries(main PRIVATE swarm::core)
```

```bash
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE="$VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
cmake --build build
```

For WebAssembly, the community triplet with emsdk active:
`-DVCPKG_TARGET_TRIPLET=wasm32-emscripten
-DVCPKG_CHAINLOAD_TOOLCHAIN_FILE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"`.
`test/consumer/` is the project CI builds this way.

### Versions

Before 1.0, any minor release of swarm-core may break its API
([its API policy](https://github.com/swarm-routing/ns3-swarm-core/blob/main/docs/api-policy.md)),
and the installed package's version file accepts the same `0.y` minor only
(`find_package(swarm-core 0.4 CONFIG)`). Pin the exact version with
`overrides`, as above, until 1.0. A `version>=` constraint with a baseline
only sets a minimum: vcpkg may still pick a newer minor that another
dependency asks for, so it does not protect you from a breaking 0.y.

## How a port is bumped

Never by hand. When a library publishes a release, its release workflow
(swarm-routing/.github `reusable-release.yml`, input `vcpkg-ports`) runs

```bash
python3 -I tools/port_bump.py bump --port swarm-core --tag v0.4.0
```

in a checkout of this repository, which downloads the release asset named in
the port's `portfile.cmake`, checks it against the release's `SHA256SUMS`,
writes its SHA512 and the version, computes the port's git-tree with git, and
updates `versions/`; the org bot then opens the PR. A person runs the same
command for a missed release and opens the PR themselves. A port that is not
in `ports/` yet is created from `templates/<port>/` on its library's first
release. `python3 -I tools/port_bump.py check` says whether `versions/`
matches `ports/`; CI also runs vcpkg's `x-ci-verify-versions`.

## What is not a port

The ns-3 modules (swarm-core's `model/`, each protocol's `ns3/`, ns3-tools'
`routing-bench`) are ns-3 contrib modules built inside an ns-3 tree, and
vcpkg has no ns-3 port to build them on; they ship as release tarballs and
images (verdict: swarm-routing/.github#440). In-org repositories take
swarm-core by its release lock, not through this registry
([CONTRIBUTING "Dependencies"](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#dependencies)).

<!-- org-sync:begin develop -->
## Develop

New here? [docs/development.md](docs/development.md) is the developer guide:
the tools to install, how to get the code and its dependencies, how to
build, test, run and lint it, the Docker images, what CI checks and how to
read a red run. How changes are proposed, reviewed and released is the org's
[CONTRIBUTING.md](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md).
A regression in a released version gets an RCAPA (root cause analysis with
corrective and preventive actions): [docs/rcapa/README.md](docs/rcapa/README.md)
is this project's flow and its index.
<!-- org-sync:end develop -->

## Contributing

Contributions from forks are welcome: see
[Outside contributions](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#outside-contributions)
(sign off every commit with `git commit -s`).

## Epics

<!-- epics:begin -->
<!-- Generated by swarm-routing/.github tools/epics/epics.py from the issues labelled `epic`; edit the issues, then re-run it. -->

What is planned and in progress here: the issues labelled [`epic`](https://github.com/swarm-routing/vcpkg-registry/issues?q=label%3Aepic). An epic's open sub-issues carry a `priority:*` and a `model:*` label, so a contributor or an AI agent can pick one up ([how issues work](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#issues)). The whole org's plan: the [roadmap](https://github.com/swarm-routing/.github/blob/main/ROADMAP.md#epics).

| Epic | Status | Sub-issues closed |
|------|--------|-------------------|
| [#10](https://github.com/swarm-routing/vcpkg-registry/issues/10) developer experience: a newcomer can build, test and contribute from the docs alone | In progress | 1 / 2 |

<!-- epics:end -->

## Licence

See [LICENSING.md](LICENSING.md).
