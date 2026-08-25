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
`../ms2ex-file-ingest` Docker tool (see `docs/CLIENT_METADATA.md`). Local runs
expect a `.env` (see `.env-example`) and a running Redis.

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

## Architecture notes

- **Never mention the reference implementation in comments or code.**
  Comments must describe behavior in domain terms only. Never name another
  implementation, its classes, methods, files, or identifiers (packet
  builders, serializers, counter names, etc.) anywhere in `lib/` or
  `config/`. Cross-implementation comparison notes live in a local,
  git-ignored file (`docs/reference-deltas.md`) and must never be
  committed.

- **Never commit without explicit approval.** Implement changes, compile,
  and verify, but leave them uncommitted so the user can test against the
  game client first. Commit only after the user confirms the fix works.

- `lib/ms2ex/storage.ex` is a lazy, immutable cache: documents are fetched
  from Redis on first access into the `:metadata` ETS table and never
  invalidated. Missing keys are negative-cached. Do not add TTLs, eviction,
  or eager boot-time loading.
- Metadata values are plain maps decoded from ETF (`:erlang.binary_to_term/1`);
  their shapes are defined by the projection layer in `../ms2ex-file-ingest`.
