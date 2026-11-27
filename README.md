# vcpkg-registry

<!-- org-sync:begin badges -->
| Group | Badges |
| --- | --- |
| Release | [![Release](https://img.shields.io/github/v/release/swarm-routing/vcpkg-registry?sort=semver&cacheSeconds=1800)](https://github.com/swarm-routing/vcpkg-registry/releases) [![Cite](https://img.shields.io/badge/cite-CITATION.cff-blue)](CITATION.cff) [![Licence: MIT OR GPL-2.0-only](https://img.shields.io/badge/licence-MIT%20OR%20GPL--2.0--only-blue)](LICENSING.md) |
| Trust | [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/swarm-routing/vcpkg-registry/badge)](https://scorecard.dev/viewer/?uri=github.com/swarm-routing/vcpkg-registry) [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/16824/badge)](https://www.bestpractices.dev/projects/16824) |
| Stack | [![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue?logo=python)](AGENTS.md) |
| Community & docs | [![Colony Arena: vcpkg-registry](https://img.shields.io/badge/Colony%20Arena-project%20page-orange)](https://swarm-routing.github.io/projects/vcpkg-registry/) [![Open RCAPA](https://img.shields.io/github/issues/swarm-routing/vcpkg-registry/rcapa?label=open%20RCAPA&color=blue)](https://github.com/swarm-routing/vcpkg-registry/blob/main/docs/rcapa/README.md) [![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)](https://www.conventionalcommits.org) |
<!-- org-sync:end badges -->

The swarm-routing org's [vcpkg git registry](https://learn.microsoft.com/vcpkg/maintainers/registries)
for the simulator-free C++ cores it releases. Each port builds a published
release asset, checked by its SHA512, and installs the library as a CMake
package. CI installs every port on `x64-linux` and `wasm32-emscripten` and
builds a `find_package` consumer (epic swarm-routing/.github#436).

| Port | Version | Library | Package and target | Source |
|------|---------|---------|--------------------|--------|
| `swarm-core` | [![vcpkg: swarm-core](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fswarm-routing%2Fvcpkg-registry%2Fmain%2Fports%2Fswarm-core%2Fvcpkg.json&query=%24%5B%22version-semver%22%5D&label=vcpkg%20swarm-core)](ports/swarm-core) | the shared swarm-routing primitives (`core/` of [ns3-swarm-core](https://github.com/swarm-routing/ns3-swarm-core)), C++23 (since 0.4.0) | `find_package(swarm-core CONFIG REQUIRED)`, `swarm::core` | `swarm-core-<ver>.tar.gz` of each release |
| `ns3` | [![vcpkg: ns3](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fswarm-routing%2Fvcpkg-registry%2Fmain%2Fports%2Fns3%2Fvcpkg.json&query=%24.version&label=vcpkg%20ns3)](ports/ns3) | stock [ns-3](https://www.nsnam.org), the release the org's images build, with their modules, shared libraries; x64-linux only (#76) | `find_package(ns3 CONFIG REQUIRED)`, `ns3::<module>` (`ns3::core`, `ns3::wifi`, …) | `ns-<ver>.tar.bz2` from nsnam.org, checked against the SHA-1 its download page lists |
| `sim-tools-ns3` | [![vcpkg: sim-tools-ns3](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fswarm-routing%2Fvcpkg-registry%2Fmain%2Fports%2Fsim-tools-ns3%2Fvcpkg.json&query=%24%5B%22version-semver%22%5D&label=vcpkg%20sim-tools-ns3)](ports/sim-tools-ns3) | sim-tools' ns-3 modules (its `ns3/` folder: routing-bench, the comparison harness with the stock arms), on the `ns3` port; one port per simulator folder of [sim-tools](https://github.com/swarm-routing/sim-tools); x64-linux only | `find_package(sim-tools-ns3 CONFIG REQUIRED)`, `ns3::routing-bench`; `routing-compare` in `tools/sim-tools-ns3/` | `routing-bench-<ver>.tar.gz` of each release |
| `swarm-adapter-ns3` | [![vcpkg: swarm-adapter-ns3](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Fswarm-routing%2Fvcpkg-registry%2Fmain%2Fports%2Fswarm-adapter-ns3%2Fvcpkg.json&query=%24%5B%22version-semver%22%5D&label=vcpkg%20swarm-adapter-ns3)](ports/swarm-adapter-ns3) | swarm-adapter-ns3's ns-3 module `swarm-core` (`SwarmRoutingBase`, the link monitors, the helpers), on the `ns3` and `swarm-core` ports (since 2.1.0, `SWARM_CORE_FROM_PACKAGE`); x64-linux only | `find_package(swarm-adapter-ns3 CONFIG REQUIRED)`, `ns3::swarm-core`; `swarm-core-seed` in `tools/swarm-adapter-ns3/` | `swarm-core-<ver>.tar.gz` of each [swarm-adapter-ns3](https://github.com/swarm-routing/swarm-adapter-ns3) release, saved as `swarm-adapter-ns3-<ver>.tar.gz` |

The ns-3 bugs of the org's
[register](https://github.com/swarm-routing/sim-tools/blob/main/docs/ns3-bugs.md),
on ns-3.49: **NS3-001**, stock AODV livelocks in a zero-time ICMP storm. The
port applies the upstream fix,
[nsnam/ns-3-dev!3101](https://gitlab.com/nsnam/ns-3-dev/-/merge_requests/3101)
at its head `d3fbcacb` (`ports/ns3/patches/`), when the source has the bug: it
skips the patch on a release without `SendIcmpNoRoute` or one that already has
the fix, and stops on one that changed that code
(maintainer decision 2026-11-25). So on 3.49 this port is not stock ns-3, as
the org's images are; routing-bench keeps its `IcmpErrorGuardHelper` either
way. **NS3-002**, AODV and DSDV order sockets by heap address
(routing-bench's `--isolateArms`); **NS3-003**, DSDV on a route with a null
output device (avoid DSDV on multi-interface topologies). It is not built for
`wasm32-emscripten`: ns-3 has no WebAssembly support, and ns-3 needs shared
libraries, which that triplet does not build (#76). Its headers need C++23
(ns-3.49's minimum), which its targets do not set:
`target_compile_features(main PRIVATE cxx_std_23)`. The port also installs
`share/ns3/contrib/`, the project the ns-3 module ports build an ns-3
contrib module with, outside an ns-3 tree.

Each port's description is its upstream repository's GitHub description
(declared as code there), written by `tools/port_bump.py` at every bump
(`refresh` re-reads it between releases, weekly in CI:
`.github/workflows/port-descriptions.yml`), so it cannot go stale.

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
| `q-swarm-core` | `q-swarm-core`, `qswarm::core` | a Q-Swarm release (the package since swarm-routing/Q-Swarm#37) |
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

## The ns-3 modules

Every C++ release gets a port, the ns-3 modules included (maintainer
decision 2026-11-24, swarm-routing/.github#881, replacing the verdict of
swarm-routing/.github#440). They are built on the `ns3` port, through its
`share/ns3/contrib/` project, and installed beside it: sim-tools' modules as
`sim-tools-ns3` (one port per simulator folder of sim-tools), swarm-adapter-ns3's
module as `swarm-adapter-ns3`. In-org repositories still take swarm-core by
its release lock, not through this registry
([CONTRIBUTING "Dependencies"](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#dependencies)).

`tools/port_bump.py bump --port ns3 --tag ns-3.50` bumps ns-3 itself: the
portfile declares its tag form (`# RELEASE_TAG`) and the page that lists the
tarball's checksum (`# CHECKSUM_PAGE`), as nsnam.org is not a GitHub release.

<!-- org-sync:begin develop -->
## Develop

New here? [docs/development.md](docs/development.md) is the developer guide:
the tools to install, how to get the code and its dependencies, how to
build, test, run and lint it, the Docker images, what CI checks and how to
read a red run. How changes are proposed, reviewed and released is the org's
[CONTRIBUTING.md](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md).
Whether a regression here gets an RCAPA (root cause analysis with corrective
and preventive actions), and how: [docs/rcapa/README.md](docs/rcapa/README.md).
<!-- org-sync:end develop -->

<!-- org-sync:begin citing -->
## Releases & citing

Versions follow [SemVer](https://semver.org). Each release is listed under [Releases](https://github.com/swarm-routing/vcpkg-registry/releases), built by the org's release workflow and archived on [Zenodo](https://zenodo.org) with its own DOI.

To cite this repository, use the “Cite this repository” button (from [CITATION.cff](CITATION.cff)). It has no DOI yet: the concept DOI appears here and in the badge above once Zenodo archives its first release.

Using it in your work? Contributions are welcome, and citing it helps just as much.
<!-- org-sync:end citing -->

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
