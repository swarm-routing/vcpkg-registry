# Roadmap

Which release each piece of work serves, and what each release must show to
ship. Releases are cut on the maintainer's request only (swarm-routing/.github
CONTRIBUTING "Cutting a release"); the org-wide view is the
[org ROADMAP](https://github.com/swarm-routing/.github/blob/main/ROADMAP.md).
A version's scope is the set of issues labelled `release:vX.Y.Z`; the release
workflow's ladder gate refuses a bump whose version has no row here.

A release of the registry tags one commit of `main` (its ports, `versions/`
database and tools together) and archives it; vcpkg itself reads the
registry by baseline commit, and a port's new version arrives with its
library's release, not with one of these (maintainer decision on
[swarm-routing/.github#636](https://github.com/swarm-routing/.github/issues/636),
2026-11-17).

## Release ladder

| Release | Theme | Exit criteria |
|---|---|---|
| v0.1.0 | first tagged release | `release.yml` on `reusable-release.yml`, `.cz.toml` and `CITATION.cff` in place; the `swarm-core` port installs on `x64-linux` and `wasm32-emscripten` (`registry.yml` green on `main`); a dry run green; no open issue labelled `release:v0.1.0`; the maintainer asks for it |

## Non-goals

- No release per port bump: the library's release opens the port's PR, and
  a consumer's baseline commit picks it up without a registry release.
