# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

ms2ex is a MapleStory 2 server emulator written in Elixir (Phoenix + TCP
game/login servers). Requires Elixir ~> 1.17 on **OTP >= 28** (metadata in
Redis uses the OTP 28 ETF map layout).

## Commands

```bash
mix deps.get     # fetch dependencies
mix compile      # compile
mix test         # run tests
mix format       # format code — ALWAYS run before committing
```

Game client metadata comes from Redis, populated by the sibling
`../ms2ex-file-ingest` tool (see `docs/CLIENT_METADATA.md`). Local runs
expect a `.env` (see `.env-example`) and a running Redis.

```bash
cd ../ms2ex-file-ingest
dotnet run --project src   # re-runs are incremental (checksum per set)
```

The ingest tool also ships probe flags for inspecting raw client data without
re-ingesting (`--probe-...`; prefix with `dotnet run --project src --` for
host runs):

- `--probe-skill <id,id>` — full skill levels/motions/attacks, incl. each
  on-hit effect's `splash`/`overlap_count`/`fireCount`
- `--probe-effects <id,id>` — full additional-effect documents (dot, recovery,
  skills, tick_skills, modify_overlap, update.cancel)
- `--probe-source <effectId>` — reverse lookup: every skill and effect that
  references an effect id (attack skills, skills, tick_skills, dot.buff,
  modify_overlap)
- `--probe-ticks` — skills whose effects tick
- `--probe-trigger <folder>` — raw trigger-script XMLs under
  `trigger/<folder>/` (the map's xblock name, e.g. `52000065_qd`)

## Elixir style

- **One `alias` per line.** Never alias multiple modules on the same line,
  even inside braces:

  ```elixir
  # bad
  alias Ms2ex.{Managers, Context, Packets}

  # good
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  ```

- **Alias the upper-level module** rather than deep submodules, to avoid
  ambiguity and keep call sites short:

  ```elixir
  # preferred
  alias Ms2ex.Storage

  Storage.Items.get_meta(item_id)

  # avoid
  alias Ms2ex.Storage.Items

  Items.get_meta(item_id)
  ```

- **Fail fast on server-side data; guard only client-sent data.** Ingested
  metadata, storage documents, and manager state are ours — if their shape
  is wrong, let it crash: a loud crash (pattern match, KeyError) surfaces
  the bug immediately and points at the fix. Do not add defensive
  `Map.get`/default/`Logger.warning`-and-continue guards around it; they
  silently degrade behavior and hide the error. Validation and graceful
  handling are for data that crosses the wire from the game client, where
  a malicious or stale client must not take down a process.

- **`Mimic.copy` calls live in `test/test_helper.exs`, not in per-test `setup`
  blocks.** Copying a module there lets every test stub it; test files only
  call `Mimic.stub`. If a test needs to stub a module that isn't copied yet,
  add the `Mimic.copy` to `test_helper.exs` first.
- **Do not seed metadata in tests by writing directly to ETS.** Use the
  shared `stub_metadata/1` helper from `test/support/test_helpers.ex` instead
  of `:ets.insert(:metadata, ...)` so tests go through the same storage stub
  path consistently.
- **Never start GenServers in tests.** Test the functions directly: build a
  state map/struct, call the public state-transition function the manager's
  `handle_call`/`handle_info` delegates to, and assert on the returned state.
  Make those internal state functions public (state in → state out) rather
  than driving managers through `GenServer.call`/casts or polling with
  `wait_until` loops. Process-lifetime concerns (named registration,
  teardown, sandbox sharing) are integration concerns, not unit-test
  concerns.

## Architecture notes

- **Contexts persist, managers own state.** A context module
  (`Ms2ex.Context.*`) contains only database reads and writes — no
  processes, no packets, no manager references. Per-character or per-session
  state lives in a manager (`Ms2ex.Managers.*`) GenServer that owns it in
  memory, calls contexts to persist, and is started at login and stopped on
  disconnect (the quest, inventory, and achievement managers are the model).
  Handlers orchestrate through managers and never run queries directly;
  pre-session flows (character creation, login listings, seeds) write the
  database through contexts. State owned by a manager is never mirrored
  onto the character struct — readers query the owning manager, and
  contexts receive the data they need as arguments (see `Context.ItemStats`
  taking the equipped items).
- **Matching the reference implementation's behavior is the standing,
  assumed goal — never mention it in comments or code.** Comments must
  describe behavior in domain terms only (what the server does and why),
  never attribute it to "the reference", "matching", "mirroring", or any
  other implementation. Never name another implementation, its classes,
  methods, files, or identifiers (packet builders, serializers, counter
  names, etc.) anywhere in `lib/` or `config/`. Cross-implementation
  comparison notes live in a local, git-ignored directory (`docs/internal/`)
  and must never be committed.

- **Never commit without explicit approval.** Implement changes, compile,
  and verify, but leave them uncommitted so the user can test against the
  game client first. Commit only after the user confirms the fix works.
- **Before merging and cleaning up a worktree, do a final review against the
  reference behavior.** Re-check the full diff, look for refactor
  opportunities, and confirm the implemented behavior matches the reference as
  closely as possible before the branch is merged or the worktree is removed.

- `lib/ms2ex/storage.ex` is a lazy, immutable cache: documents are fetched
  from Redis on first access into the `:metadata` ETS table and never
  invalidated. Missing keys are negative-cached. Do not add TTLs, eviction,
  or eager boot-time loading.
- Metadata values are plain maps decoded from ETF (`:erlang.binary_to_term/1`);
  their shapes are defined by the projection layer in `../ms2ex-file-ingest`.
- **Trigger action/condition arguments arrive canonically named, never
  positional.** The client data mixes positional (`arg1`, `arg2`, ...),
  misspelled (`agr2`, `spwnPointID`, `offestRateX`) and named attributes
  for the same function across different scripts. `ms2ex-file-ingest`'s
  `TriggerScriptExtractor.ArgsDoc` renames every attribute through the
  ported definition-override table (`src/Utils/TriggerDefinitionOverride.cs`,
  `ActionOverride`/`ConditionOverride`) before snake-casing, so every
  document a trigger handler reads already carries one canonical key per
  argument (e.g. `set_mesh` is always `trigger_ids`/`visible`, never
  `arg1`/`arg2`). Handlers in `Ms2ex.Managers.Field.Trigger` must read only
  that canonical key — never add a positional or misspelled fallback, and
  never guess a canonical name by inspecting the override table alone.
  When adding or auditing a trigger action/condition, look up its real
  argument keys against a fresh ingest (dump `Storage.Triggers.get_scripts/1`
  for a script that uses it) rather than deriving the rename by hand —
  the snake-casing of some renames (e.g. `spawnPointID` → `spawnId`
  collapses to `spawn_id`, not `spawn_point_id`) is easy to get wrong by
  inspection. A rename-table change in the ingest requires re-running it
  and re-auditing every affected handler and test fixture in the same
  change.

## Roadmap, feature docs & TODOs

- `docs/ROADMAP.md` is a compact list of open items only: one line per
  item with an `[Open]`/`[Partial]` marker, linking to its feature document
  under `docs/features/`. Never let it grow long-form content or completed
  history.
- **`docs/features/` (committed) documents each feature**: how the system
  works today and what is still needed. Written for agents — packet layouts,
  data shapes, state machines, open gaps. Never mention other
  implementations or tooling; describe behavior in domain terms. When you
  implement, fix, or advance a feature, update its feature doc and the
  roadmap entry's status marker.
- **Completed work goes to `docs/CHANGELOG.md`** (one entry per landed
  change, newest first). Move nothing else there — no open work, no plans.
- **Leave `TODO` comments for unimplemented behavior.** When a code path is
  incomplete or stubbed, add a `# TODO` comment (with a short note on what
  remains) so unfinished work can be found by grepping for `TODO`.
- **Raw investigation notes live in `docs/internal/` (git-ignored)**: client
  reverse-engineering, memory-dump sessions, packet-capture diffs, live-test
  logs. When an investigation concludes, distill the durable knowledge into
  the feature's `docs/features/` document (sanitized, no history) and drop
  the rest; the internal scratch copy can stay for future digging.
