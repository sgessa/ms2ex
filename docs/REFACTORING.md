# Refactoring Roadmap

## 1. Finish extracting Character manager features into sub-modules

`Managers.Character` (327 lines) still owns several feature groups inline.
The established pattern is `Managers.Character.<Feature>` with functions that
return `{:ok, character} | :error`, matched by thin `handle_call`/`handle_cast`
wrappers in the parent module (see `stat_points.ex`, `stats.ex`, `skill.ex`).

Remaining extractions:

| Feature | Handle messages | Target file |
|---------|----------------|-------------|
| Skill cooldowns | `save_skill_cooldown`, `set_skill_cooldown`, `get_skill_cooldowns` | `managers/character/skill_cooldown.ex` |
| Experience / levelling | `earn_exp`, `set_level`, `refresh_level` | `managers/character/experience.ex` |
| Revival | already exists in `managers/character/revival.ex` – wire up | – |

`refresh_level` is a private helper that calls `Context.CharacterStats.apply` and
broadcasts a level-up; it belongs with experience, not the root module.

---

## 2. Eliminate duplicated `call`/`cast`/`process_name` boilerplate

Every named-process manager reimplements the same three-line dispatch:

```elixir
# managers/character.ex
def call(%Schema.Character{id: id}, msg) do
  if pid = Process.whereis(process_name(id)), do: GenServer.call(pid, msg), else: :error
end
def call(character_id, msg) do
  if pid = Process.whereis(process_name(character_id)), do: GenServer.call(pid, msg), else: :error
end
def cast(%Schema.Character{id: id}, msg), do: GenServer.cast(process_name(id), msg)
```

The same pattern is repeated verbatim in `GroupChat`, `PartyServer`, `Buff`, etc.

**Proposal – `Managers.GenServer` (or `use Managers.Managed`):**

```elixir
defmodule Ms2ex.Managers.Managed do
  defmacro __using__(prefix: prefix, key: key) do
    quote do
      defp process_name(id), do: :"#{unquote(prefix)}:#{id}"

      def call(%{unquote(key) => id}, msg), do: call(id, msg)
      def call(id, msg) do
        case Process.whereis(process_name(id)) do
          nil -> :error
          pid -> GenServer.call(pid, msg)
        end
      end

      def cast(%{unquote(key) => id}, msg), do: GenServer.cast(process_name(id), msg)
      def cast(id, msg), do: GenServer.cast(process_name(id), msg)
    end
  end
end
```

Usage:

```elixir
defmodule Ms2ex.Managers.Character do
  use Ms2ex.Managers.Managed, prefix: "characters", key: :id
  ...
end
```

This eliminates ~20 lines of identical code across at least four managers and
makes the nil-process guard consistent everywhere (currently `Buff` does not
guard, `Character` does).

---

## 3. Consolidate the repetitive handler pattern `lookup → act → update`

69 occurrences of `Managers.Character.lookup(session.character_id)` appear in
handlers. 34 additional `Context.Characters.update` / `Managers.Character.update`
pairs follow the lookup. A macro or helper could reduce this:

```elixir
# handlers/game/helpers/session.ex  (already imported)
def with_character(session, fun) do
  {:ok, character} = Managers.Character.lookup(session.character_id)
  fun.(character, session)
end
```

Most handlers would then become:

```elixir
def handle(packet, session) do
  with_character(session, fn character, session ->
    ...
    session
  end)
end
```

Low risk; can be done handler-by-handler without breaking anything.

---

## 4. Separate packet building from context/business logic

Several context modules (`Context.Field`, `Context.Inventory`) call
`Packets.*` directly. Context should be packet-agnostic; callers (handlers,
managers) should own the packet sends.

Affected modules include `Context.Field.broadcast_stats`, which calls
`Packets.Stats` – this is fine as a field-level broadcast helper but is a
pattern worth documenting as the limit of how far context can reach into packets.

---

## 5. Normalise `Context.Characters` (it mixes concerns)

`Context.Characters` has:
- CRUD (`get`, `update`, `delete`, `create`) – correct
- Stat-point persistence (`update_stat_points`) – belongs here
- Helpers that call other contexts (`load_equips`, `load_skills`, `maybe_discover_map`)

`load_equips` and `load_skills` are convenience loaders that return an enriched
character. They are only called at login and in tests. Consider moving them to
`Context.CharacterStats` or a dedicated `Context.CharacterLoader` to keep
`Context.Characters` focused on persistence.

---

## 6. Existing TODOs worth scheduling

| Location | Note |
|----------|------|
| `managers/character.ex:16` | `lookup_by_name` does a direct SQL query – should use the registry |
| `context/inventory.ex:300` | Inventory slots are not read from DB |
| `managers/party_server.ex:147` | Start-vote-kick packet not sent |
| `managers/character/revival.ex:131` | Free-revive coupon not consumed |
