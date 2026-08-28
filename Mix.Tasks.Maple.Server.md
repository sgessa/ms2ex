# `mix maple.server`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/mix/tasks/maple/server.ex#L1)

Starts the application with both its game TCP listeners (login, world login
and channel servers) and the Phoenix web endpoint.

To start only the game TCP listeners, use `mix maple.game`. To serve only
the web endpoint, use `mix phx.server`.

The `--no-halt` flag is automatically added so the servers keep running.

## Command line options

This task accepts the same command-line options as `mix run`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
