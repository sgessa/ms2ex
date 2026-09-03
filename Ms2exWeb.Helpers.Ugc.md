# `Ms2exWeb.Helpers.Ugc`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex_web/helpers/ugc.ex#L1)

Shared plumbing for the user generated content endpoints: reading the binary
upload envelope, storing files inside the data directory and serving them back.

Every path segment that originates from a request is validated before it
touches the filesystem, so a crafted id or file name cannot escape the data
directory.

# `upload`

```elixir
@type upload() :: %{
  type: atom(),
  character_id: integer(),
  resource_id: integer(),
  id: integer(),
  file: binary()
}
```

# `clear`

```elixir
@spec clear([String.t()]) :: :ok
```

Removes every file previously stored under `segments`.

# `owned_resource`

```elixir
@spec owned_resource(upload()) ::
  {:ok, Ms2ex.Schema.UgcResource.t()} | {:error, atom()}
```

Loads the resource an upload targets, refusing to write to content owned by a
different character.

# `publish`

```elixir
@spec publish(Ms2ex.Schema.UgcResource.t(), String.t()) ::
  {:ok, String.t()} | {:error, atom()}
```

Records the path the client should fetch a resource back from.

# `read_upload`

```elixir
@spec read_upload(Plug.Conn.t()) :: {:ok, upload()} | {:error, atom()}
```

Reads the upload envelope: a header identifying the uploader and the resource
being written, followed by the raw file bytes.

# `send_error`

```elixir
@spec send_error(Plug.Conn.t(), atom()) :: Plug.Conn.t()
```

# `send_path`

```elixir
@spec send_path(Plug.Conn.t(), {:ok, String.t()} | {:error, atom()}) :: Plug.Conn.t()
```

Answers an upload with the path the client should use from now on.

# `serve`

```elixir
@spec serve(Plug.Conn.t(), [String.t()], String.t(), String.t()) :: Plug.Conn.t()
```

Serves a stored file, or 404 when it is missing or the path is invalid.

# `store`

```elixir
@spec store([String.t()], binary()) :: :ok | {:error, atom()}
```

Writes an uploaded file under the data directory.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
