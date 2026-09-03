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

### Running on the host (no Docker)

Docker is often unavailable on this machine (restricted docker.sock). The tool
runs directly with the .NET SDK:

```bash
cd ../ms2ex-file-ingest
set -a && source .env && set +a   # MS2_DATA_FOLDER, LANGUAGE, REDIS_*
dotnet run --project src          # REDIS_HOST defaults to localhost
```

- Re-runs are incremental (CRC32C checksum per set).
- Probe flags: `dotnet run --project src -- --probe-skill <ids>`.
- If `src/obj` / `src/bin` are root-owned (container leftovers), redirect the
  build output and disable assembly-info generation:

  ```bash
  dotnet run --project src \
    -p:BaseIntermediateOutputPath=/tmp/ingest-obj/ \
    -p:OutputPath=/tmp/ingest-bin/ \
    -p:GenerateAssemblyInfo=false \
    -p:GenerateTargetFrameworkAttribute=false
  ```

### Verifying ingested content

From the ms2ex worktree (Redis settings come from `.env`):

```bash
mix run -e '
{:ok, keys} = Redix.command(Ms2ex.Redix, ["KEYS", "script:*"])
IO.puts("script docs: #{length(keys)}")
'
```

(If mix complains about an old Elixir version, prefix with `mise exec --`.)

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
| `quest:<id>` + `quest:index` | quest metadata, rewards, conditions, npc/type/chapter/auto-start index |
| `script:<id>`        | npc + quest talk scripts: states, contents, buttons |
| `map:<id>`           | boundings, spawns, portals                      |
| `table:<filename>`   | job.xml, itemoption\*.xml, nametagsymbol.xml, magicpath.xml, chatemoticon.xml, exp\*.xml, drop tables, userstat, server.constants |

Values are Erlang external term format (ETF) with atom keys, decoded with
`:erlang.binary_to_term/1`. The map encoding follows OTP 28's layout — the
server must run on OTP >= 28.

## Troubleshooting

If MS2EX fails to start or exhibits unexpected behavior, verify that:
- Redis is running and accessible (connection settings in `config/dev.exs`)
- The ingest has been run against that Redis instance
- The client data folder contains all three m2d archives
