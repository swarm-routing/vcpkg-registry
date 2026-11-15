# CONTEXT.md — orientation and history

Background an agent or a new contributor needs that does not belong in
`AGENTS.md`: domain notes, current state, glossary, open questions. Read the
section a task needs, not the whole file.

## Current state

Created by the maintainer on 2026-11-15 (maintainer decision that day: start
the registry now, not after swarm-core v1.0.0; design in
swarm-routing/ns3-swarm-core#135). Epic swarm-routing/.github#436.

## Glossary

- **port**: a directory `ports/<name>/` (`vcpkg.json`, `portfile.cmake`) that tells vcpkg how to build one library version.
- **git-tree**: the git object id of a port's directory at one version (`git rev-parse <commit>:ports/<name>`); `versions/<x>-/<name>.json` maps each version to one.
- **baseline**: `versions/baseline.json`, the version a consumer gets when it pins nothing else.

## Open questions
