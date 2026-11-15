# Licensing

Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing).
Licensed per directory, as AntHocNet
([LICENSING.md](https://github.com/swarm-routing/AntHocNet/blob/main/LICENSING.md),
[ADR-0028](https://github.com/swarm-routing/AntHocNet/blob/main/docs/adr/0028-core-is-dual-licensed.md)).

| Path | What | Licence |
|------|------|---------|
| `ports/`, `templates/`, `versions/`, `tools/`, `test/`, `.github/`, `Makefile` | the ports, the versions database, the renderer, CI | `MIT OR GPL-2.0-only` |
| `docs/`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `SECURITY.md`, `LICENSING.md` | docs (org rule 1) | `GPL-2.0-only` |
| everything else | | `MIT OR GPL-2.0-only` |

`MIT OR GPL-2.0-only` means you may use that code under either licence, at
your option ([LICENSE-MIT](LICENSE-MIT) or [LICENSE](LICENSE)). Every source
file carries its SPDX identifier; CI checks it (`reusable-licence-check.yml`).
