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

- **`Mimic.copy` calls live in `test/test_helper.exs`, not in per-test `setup`
  blocks.** Copying a module there lets every test stub it; test files only
  call `Mimic.stub`. If a test needs to stub a module that isn't copied yet,
  add the `Mimic.copy` to `test_helper.exs` first.
- **Do not seed metadata in tests by writing directly to ETS.** Use the
  shared `stub_metadata/1` helper from `test/support/test_helpers.ex` instead
  of `:ets.insert(:metadata, ...)` so tests go through the same storage stub
  path consistently.

## Architecture notes

- **Contexts persist, managers own state.** A context module
  (`Ms2ex.Context.*`) contains only database reads and writes — no
  processes, no packets, no manager references. Per-character or per-session
  state lives in a manager (`Ms2ex.Managers.*`) GenServer that owns it in
  memory, calls contexts to persist, and is started at login and stopped on
  disconnect (the quest, inventory, and achievement managers are the model).
  Handlers orchestrate through managers and never run queries directly;
  pre-session flows (character creation, login listings, seeds) write the
  database through contexts.
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

## Roadmap & TODOs

- **Update `docs/ROADMAP.md` whenever you touch a feature.** When an item is
  implemented, fixed, or advances, update its `[Open]` / `[Partial]` status or
  move it into "Recently completed". Completed items must be moved out of the
  numbered backlog sections into "Recently completed". Keep the roadmap the
  source of truth for what is still missing.
- **Leave `TODO` comments for unimplemented behavior.** When a code path is
  incomplete or stubbed, add a `# TODO` comment (with a short note on what
  remains) so unfinished work can be found by grepping for `TODO`.
- **Write investigation notes under `docs/internal/`.** When digging into a
  feature, a divergence, or a client-packet layout, capture findings in a
  per-feature note in `docs/internal/` (git-ignored) instead of one monolithic
  comparison document. Update the matching `docs/ROADMAP.md` item when the
  investigation concludes.
