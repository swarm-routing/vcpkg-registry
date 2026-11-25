# Licensing

Copyright (c) 2026 Daniel Joppi (https://github.com/swarm-routing).
Licensed per directory, as AntHocNet
([LICENSING.md](https://github.com/swarm-routing/AntHocNet/blob/main/LICENSING.md),
[ADR-0028](https://github.com/swarm-routing/AntHocNet/blob/main/docs/adr/0028-core-is-dual-licensed.md)).

| Path | What | Licence |
|------|------|---------|
| `ports/`, `templates/`, `versions/`, `tools/`, `test/`, `.github/`, `Makefile` | the ports, the versions database, the renderer, CI | `MIT OR GPL-2.0-only` |
| `ports/ns3/patches/` | ns-3's own code: upstream fixes the `ns3` port applies, each named with its merge request and commit in `ports/ns3/portfile.cmake` (NS3-001: nsnam/ns-3-dev!3101 at `d3fbcacb`) | `GPL-2.0-only` |
| `test/consumer/ns3/` | the ns-3 ports' consumer: it includes ns-3's headers (GPL-2.0-only), so the dual-licensed tree must not hold it | `GPL-2.0-only` |
| `docs/`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `SECURITY.md`, `LICENSING.md` | docs (org rule 1) | `GPL-2.0-only` |
| everything else | | `MIT OR GPL-2.0-only` |

<!-- org-sync:begin licence-texts -->
Texts: [`LICENSE`](LICENSE) (GPL-2.0) and [`LICENSE-MIT`](LICENSE-MIT) (the
MIT option). Each source file states its licence in its
`SPDX-License-Identifier` line; CI checks it
(`swarm-routing/.github` `cmd/check-headers`; locally `make headers`).
<!-- org-sync:end licence-texts -->
