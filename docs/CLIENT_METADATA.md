# Game Client Metadata

MS2EX requires game client metadata to function properly.

## Metadata System Overview

1. **Source Data**: The original game client archives (`Xml.m2d`, `Server.m2d`,
   `Resource/Exported.m2d`) contain the game data.

2. **Ingest**: [ms2ex-file-ingest](../ms2ex-file-ingest) (standalone C# tool,
   extracted from Maple2's `Maple2.File.Ingest`) parses the client archives and
   writes ETF-encoded documents **directly to Redis** — no MySQL involved.

3. **Server Usage**: MS2EX lazily loads documents from Redis into ETS on first
   access (`Ms2ex.Storage`). Data is immutable while the server runs; keys
   missing from Redis are negatively cached.

```
client files (m2d) → ms2ex-file-ingest → Redis → ms2ex
```

## Setup

```bash
cd ms2ex-file-ingest
cp .env-example .env    # point MS2_DATA_FOLDER at your client folder
docker compose build
docker compose run --rm ms2ex-file-ingest
```

Re-runs are incremental: each set carries a CRC32C checksum in the Redis hash
`ingest:checksum` and unchanged sets are skipped. Use `--drop-data` to force a
full re-write.

See [ms2ex-file-ingest README](../ms2ex-file-ingest/README.md) for details.

## What gets ingested

| Redis set            | Contents                                        |
|----------------------|-------------------------------------------------|
| `item:<id>`          | slots, limits, options, functions, box contents |
| `npc:<id>`           | basic/class/level, model, stats                 |
| `skill:<id>`         | properties + per-level data                     |
| `additional-effect:` | buff properties, shield, status values          |
| `map:<id>`           | boundings, spawns, portals                      |
| `table:<filename>`   | job.xml, itemoption\*.xml, nametagsymbol.xml, magicpath.xml, chatemoticon.xml, exp\*.xml |

Values are Erlang external term format (ETF) with atom keys, decoded with
`:erlang.binary_to_term/1`. The map encoding follows OTP 28's layout — the
server must run on OTP >= 28.

## Troubleshooting

If MS2EX fails to start or exhibits unexpected behavior, verify that:
- Redis is running and accessible (connection settings in `config/dev.exs`)
- The ingest has been run against that Redis instance
- The client data folder contains all three m2d archives
