# `Ms2ex.Net.Session`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/net/session.ex#L1)

TCP client and protocol for ms2

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `init`

# `init`

Initiates the handler, acknowledging the connection was accepted.
Finally it makes the existing process into a `:gen_server` process and
enters the `:gen_server` receive loop with `:gen_server.enter_loop/3`.

# `start_link`

Starts the handler with `:proc_lib.spawn_link/3`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
