# `Ms2ex.Storage`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/storage.ex#L1)

Lazy, Redis-backed metadata cache.

Metadata documents (written by the `ms2ex-file-ingest` tool as ETF blobs)
are fetched from Redis on first access, decoded with
`:erlang.binary_to_term/1`, and cached in the `:metadata` ETS table.
Subsequent lookups of the same key are pure memory reads.

Ingested data is immutable while the server runs: there is no invalidation.
Keys missing from Redis are negatively cached (`:missing` tombstones) so
repeated lookups of nonexistent ids never hit Redis again.

# `id`

```elixir
@type id() :: String.t() | integer()
```

# `set`

```elixir
@type set() :: atom()
```

# `get`

```elixir
@spec get(set(), id()) :: map() | nil
```

# `get_from_redis`

```elixir
@spec get_from_redis(String.t()) :: {:ok, binary() | nil} | {:error, term()}
```

Reads a raw blob straight from Redis without touching the cache.

# `load`

```elixir
@spec load(String.t()) :: map() | nil
```

Fetches a single document from Redis and caches it. Missing keys are
stored as tombstones so later lookups skip Redis entirely.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
