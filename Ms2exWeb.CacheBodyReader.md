# `Ms2exWeb.CacheBodyReader`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex_web/plugs/cache_body_reader.ex#L1)

Keeps the raw request body around. The game client posts binary payloads that
the parsers would otherwise consume before a controller can read them.

# `read`

```elixir
@spec read(Plug.Conn.t()) ::
  {:ok, binary()} | {:error, :empty | :too_large | :malformed}
```

Returns the binary body of a request, cached or not yet read.

# `read_body`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
