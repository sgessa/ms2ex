# `Ms2ex.Context.Ugc`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/ugc.ex#L1)

Persistence for user generated content resources and the files uploaded for
them. A resource row is created by the game server when a client announces an
upload; the web server then stores the file and records the path the client
should fetch it back from.

# `create`

```elixir
@spec create(integer(), atom()) ::
  {:ok, Ms2ex.Schema.UgcResource.t()} | {:error, Ecto.Changeset.t()}
```

Creates a resource owned by `character_id` and returns it.

# `data_dir`

```elixir
@spec data_dir() :: String.t()
```

Root directory holding every uploaded file. Configurable so deployments can
point it at a persistent volume.

# `get`

```elixir
@spec get(integer()) :: Ms2ex.Schema.UgcResource.t() | nil
```

# `update_path`

```elixir
@spec update_path(Ms2ex.Schema.UgcResource.t(), String.t()) ::
  {:ok, Ms2ex.Schema.UgcResource.t()} | {:error, Ecto.Changeset.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
