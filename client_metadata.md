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
  cp .env-example .env
  dotnet run --project src
```
  
See [ms2ex-file-ingest README](../ms2ex-file-ingest/README.md) for details.

### Verifying ingested content

From the ms2ex worktree (Redis settings come from `.env`):

```bash
mix run -e '
{:ok, keys} = Redix.command(Ms2ex.Redix, ["KEYS", "script:*"])
IO.puts("script docs: #{length(keys)}")
'
```

Re-runs are incremental: each set carries a CRC32C checksum in the Redis hash
`ingest:checksum` and unchanged sets are skipped. Use `--drop-data` to force a
full re-write.

Values are Erlang external term format (ETF) with atom keys, decoded with
`:erlang.binary_to_term/1`. The map encoding follows OTP 28's layout — the
server must run on OTP >= 28.
