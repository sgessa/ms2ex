# `mix maple.game`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/mix/tasks/maple/game.ex#L1)

Starts the application and its game TCP listeners (login, world login and
channel servers) without serving the Phoenix web endpoint.

This is the game-server counterpart of `mix phx.server`. To also serve the
web endpoint, use `mix maple.server`.

The `--no-halt` flag is automatically added so the listeners keep running.

## Command line options

This task accepts the same command-line options as `mix run`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
