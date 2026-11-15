# vcpkg-registry

<!-- org-sync:begin badges -->
| Group | Badges |
| --- | --- |
| Release | [![Licence: MIT OR GPL-2.0-only](https://img.shields.io/badge/licence-MIT%20OR%20GPL--2.0--only-blue)](LICENSING.md) |
| Trust | [![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/swarm-routing/vcpkg-registry/badge)](https://scorecard.dev/viewer/?uri=github.com/swarm-routing/vcpkg-registry) |
| Stack | [![Python 3.10+](https://img.shields.io/badge/python-3.10%2B-blue?logo=python)](AGENTS.md) |
| Community & docs | [![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow)](https://www.conventionalcommits.org) |
<!-- org-sync:end badges -->

The swarm-routing org's [vcpkg git registry](https://learn.microsoft.com/vcpkg/maintainers/registries)
for the simulator-free C++ cores it releases. Each port builds a published
release asset, checked by its SHA512, and installs the library as a CMake
package. CI installs every port on `x64-linux` and `wasm32-emscripten` and
builds a `find_package` consumer (epic swarm-routing/.github#436).

| Port | Library | Package and target | Source |
|------|---------|--------------------|--------|
| `swarm-core` | the shared swarm-routing primitives (`core/` of [ns3-swarm-core](https://github.com/swarm-routing/ns3-swarm-core)), C++20 | `find_package(swarm-core CONFIG REQUIRED)`, `swarm::core` | `swarm-core-<ver>.tar.gz` of each release |

The protocol cores (ARA, BeeAdHoc, Termite, HOPNET, AntHocNet) follow once
each installs as a CMake package (epic swarm-routing/.github#436).

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
  "overrides": [{ "name": "swarm-core", "version": "0.3.0" }]
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
(`find_package(swarm-core 0.3 CONFIG)`). Pin the exact version with
`overrides`, as above, until 1.0. A `version>=` constraint with a baseline
only sets a minimum: vcpkg may still pick a newer minor that another
dependency asks for, so it does not protect you from a breaking 0.y.

## How a port is bumped

Never by hand. When a library publishes a release, its release workflow
(swarm-routing/.github `reusable-release.yml`, input `vcpkg-ports`) runs

```bash
python3 -I tools/port_bump.py bump --port swarm-core --tag v0.3.0
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

## Contributing

Contributions from forks are welcome: see
[Outside contributions](https://github.com/swarm-routing/.github/blob/main/CONTRIBUTING.md#outside-contributions)
(sign off every commit with `git commit -s`).

## Licence

See [LICENSING.md](LICENSING.md).
