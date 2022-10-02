# MS2EX - MapleStory 2 Server Emulator written in Elixir

Instructions:

  * Install LUA dependencies with `apt install libluajit-5.1-dev`

  * Install dependencies with `mix deps.get`
  * Configure database and game settings in `config/dev.exs`
  * Set up and seed a new database with `mix ecto.reset`
  * Start with `mix run --no-halt`
