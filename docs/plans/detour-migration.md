# Plan: run navigation on Detour

Status: **implemented** — the native runtime landed and the in-Elixir
geometry core was deleted. This document stays as the record of what was
built and why; current behavior lives in
[the navmesh feature doc](../features/navmesh.md).

How it landed (compressed from the phases below): the vendored Detour C
sources compile into the NIF crate (`native/navigation`, no third-party
bindings crate — the published ones were stale against the sys layer);
the ingest sinks the full mesh-set binary under `navmesh_bin`; the NIF
parses the `MSET` container and hands the C-layout tiles to the library
as-is; queries run with the (2, 4, 2) query box and a corridor must reach
the goal poly (stacked floors never connect). Synthetic mesh-set fixtures
(the crate's `gen_fixtures` binary) drive the behavioral suite. The
shadow/differential phase and the config flag were dropped at cutover —
the fixtures, the reference audit on this branch and live replay cover
the verification instead. Still open: the full ingest `--navmesh` re-run
so every map carries a binary mesh, and the mesh-era patrol workarounds
(the `TODO`s in `patrol.ex` / `npc.ex`) due for removal now that the
runtime is native.

Related: [navmesh feature doc](../features/navmesh.md).

---

The original plan follows.


Replace the hand-ported navigation geometry core with the upstream Detour
library (recast-navigation, C) behind a thin native (NIF) boundary, keeping
`Ms2ex.Navigation`'s public API and the ingest pipeline unchanged in shape.

## Why

The geometry core in `lib/ms2ex/navigation.ex` — edge welding with tolerant
T-junction overlaps, the grid index, nearest-poly resolution, detail-mesh
height sampling, A*, and the string-pulling funnel — is a hand port of
Detour's query algorithms. Every part of it has produced at least one
correctness bug, each requiring the upstream behavior to be re-derived
before it could be fixed:

- funnel tighten/pinch comparison signs inverted (zig-zag patrol routes)
- the polygon winding contract undocumented (the port's signs are
  winding-sensitive; test fixtures were wound the wrong way)
- tolerant weld ignored height, linking vertically stacked floors and
  teleporting routes between levels
- a link-merge crash on maps with both exact and tolerant neighbor links
- the over-poly climb allowance in the wrong units (70 m instead of 0.7 m)

The mesh itself is built by DotRecast — the same algorithms the runtime
re-implements. Running the library natively removes this entire bug class,
and the build-time artifacts it ships (computed links, BV-trees) delete the
code we keep getting wrong when re-deriving them from raw polygons. It also
opens the door to Detour's crowd manager for mob steering later.

The cost is one small NIF, a Rust toolchain in CI, and losing direct iex
introspection of nav internals (mitigated by the differential harness
below).

## What already exists (verified)

- **The full mesh binary is already being written.** After building, the
  ingest serializes the complete mesh set via `DtMeshSetWriter` with
  `cCompatibility: true` — the C struct layout — to
  `navmeshes/{xblock}.navmesh`. Format: an `MSET` magic + version header,
  navmesh params, then per tile: `tileRef`, `dataSize`, a zeroed alignment
  int, and the tile blob (header + polys + verts + links + detail
  meshes/verts/tris + BV-tree + off-mesh connections).
- **The bytes are already collected for sinking.** `NavMeshMapper`
  accumulates them in `navmeshEntries`, which nothing consumes — the Redis
  plumbing is half-wired and just needs a sink write.
- **Size is a wash.** 52000101: ~88 KB ETF projection vs ~128 KB full
  binary. Real meshes are small (727–1524 polys).
- **The current implementation is correct and pinned by tests** (L-corner,
  stacked floors, snap cases) — it becomes the parity oracle for cutover.

## Target architecture

```
ingest (DotRecast build)
  └─ full mesh-set bytes ──► Redis ("navmesh_bin" set, per xblock)
                                └─ NIF loader (dtNavMesh from tiles, cached
                                   in :persistent_term per xblock)
                                     └─ queries (path / snap / validity)
```

Decisions:

1. **Rust NIF via Rustler** (`native/navigation/`), using the Rust bindings
   crate for recast-navigation, or vendoring upstream C via `build.rs` if
   the crate lags. Rationale: memory safety at the boundary (a bug becomes
   an error tuple, not a VM crash), Rustler catches panics, cargo builds
   integrate with `mix compile`. We do not hand-write C.
2. **The public API does not change.** `find_path/3`, `snap_to_floor/2`,
   `valid_position?/2`, `has_navmesh?/1` keep signatures and semantics;
   patrol and mob walkers are untouched.
3. **Coordinate transforms stay in Elixir** (client Z-up ↔ navmesh Y-up,
   1/100 scale). The NIF speaks navmesh-space floats only.
4. **Caching policy unchanged**: lazy, immutable, `:persistent_term` keyed
   by xblock — the value becomes the loaded mesh resource.
5. **The ETF projection is kept through the migration** for differential
   testing and inspection; removing it is a later cleanup.

## NIF surface (small)

- `load_mesh(binary) :: resource | error` — parse the mesh-set binary and
  add each tile to a `dtNavMesh`
- `find_path(mesh, from, to) :: {:ok, [{x,y,z}, ...]} | :error` — wraps
  `findPath` + `findStraightPath`; corners carry detail-mesh heights like
  today's endpoints
- `snap(mesh, pos) :: {:ok, {x,y,z}} | :error` — wraps `findNearestPoly`
  (half extents 2 × 4 × 2 navmesh meters, matching today's query box) +
  `closestPointOnPoly`
- `position_on_mesh?(mesh, pos) :: boolean` — wraps `queryPolygons`
- later, optional: `move_along_surface`, `raycast`, crowd manager

Query filter: the default filter with the same area costs and flags the
ingest's mesher emits (pin them in one place, shared with the ingest
settings).

## Phases

### Phase 0 — data + fixtures (no runtime change)

- Ingest: sink `navmeshEntries` to Redis under a raw set (key per xblock).
  Hash gating and the local file cache are unaffected.
- Generate **synthetic** binary fixtures (L-shape, stacked floors, ramp)
  with an ingest-side generator; commit them under `test/fixtures/navmesh/`
  (synthetic geometry — not client-derived, safe to publish). Existing
  tests keep their ETF stubs during the migration and additionally load
  these fixtures for NIF parity.
- Acceptance: every xblock's bytes land in Redis; the ingest's own tests
  round-trip them through `DtMeshSetReader`.

### Phase 1 — loader + parity harness

- Rustler skeleton: `compilers: [:rustler] ++ Mix.compilers()`, crate at
  `native/navigation`; CI gains a Rust toolchain (see below).
- Rust: parse the mesh-set binary (header, params, tiles — including the
  compatibility alignment int), construct the `dtNavMesh`, expose
  `load_mesh`. Round-trip tests against the fixtures; malformed input
  returns `error`, never crashes.
- Differential harness (a mix task or `:differential`-tagged tests): pull
  real meshes and query pairs from Redis, run the Elixir implementation and
  the NIF, diff corner lists within epsilon, report mismatches.
- Acceptance: `load_mesh` succeeds for all Redis meshes; the harness runs
  end to end.

### Phase 2 — queries in shadow mode

- Implement `find_path` / `snap` / `position_on_mesh?`; a config flag picks
  the implementation (default: Elixir); the differential harness explains
  every difference.
- Outputs may differ legitimately at the margins (collinear ties, float
  noise, policy constants). **Each diff must be explained by a named
  upstream policy** — never tuned away silently.
- Acceptance: the corpus shows zero unexplained mismatches; the cutscene
  map's routes match the current implementation; all existing navigation
  tests pass when run against the NIF via the Phase 0 fixtures.

### Phase 3 — cutover + deletion

- Flip the default, soak, remove the flag.
- Drop the mesh-era compensations the migration obsoletes (each carries a
  `TODO` in the code): keep authored spawn positions verbatim (no
  grounding), end patrol legs at the mesh-snapped waypoint (no appended
  authored tail; the raw target stays only for air waypoints), and let a
  model without a walk sequence stand still (no Run_A substitution). The
  ingest builds meshes from the same collision the client renders, so
  these workarounds — from the broken-cube-index era — have no remaining
  justification once the runtime rides the same queries
- Delete from `navigation.ex`: `astar`, `funnel`/`portal_winding`/
  `tri_area2`/`seg_dist2`/`emit_corner`, `weld_edges`/`collinear_overlap`/
  `heights_converge?`, `build_grid`, `nearest_poly_entry`/`poly_closest`/
  `boundary_result`/`poly_detail_tris`/`poly_height` — roughly 600 lines.
  Keep: transforms, storage/caching, the façade, and the behavioral tests
  (they are the spec).
- Docs: rewrite `features/navmesh.md` for the native runtime, changelog
  entry, roadmap update.
- Acceptance: no references to the deleted helpers; full suite green; live
  cutscene verified against the client.

### Phase 4 — optional, later

- Detour crowd manager for mob steering.
- Stop projecting the ETF document (one release after cutover), and
  re-evaluate whether the ingest still needs the local `navmeshes/` files
  beyond incremental-run caching.

## Testing

- **Behavioral tests are unchanged** — they pin the contract (L-corner
  emits 3 points; stacked floors return `:error`; straight paths never
  duplicate the goal; snap cases with exact coordinates).
- **Fixtures** are synthetic binaries, regenerable by the ingest-side
  generator, committed so CI never needs client data.
- **Differential corpus** tests tagged `:differential`, running only when
  Redis holds ingested data (skipped in CI, run locally against a real
  ingest).
- **Rust unit tests**: loader round-trips, malformed binaries, query edge
  cases (start on portal, goal on poly edge).

## CI and toolchain

- `ci.yml` gains a Rust toolchain step before `mix test` (cargo via the
  repo's mise config); keep postgres + redis services as-is.
- Optional nightly ASan build of the NIF test suite.
- README/CONTRIBUTING: document the cargo requirement; `mix compile` fails
  loudly if the toolchain is missing (Rustler default behavior).

## Risks

- **Binary format drift** between the C# writer and the native reader.
  Both descend from the same format and the writer targets C layout
  (`cCompatibility: true`); the loader checks the magic + version and
  round-trips in CI. Pin the DotRecast version in the ingest alongside.
- **VM stability.** Rustler + no panics across the boundary; queries are
  microseconds (no dirty-scheduler complexity); loads are one-shot per map.
- **Contributor friction** (cargo toolchain). Mitigated by mise config and
  CI as the source of truth.
- **Marginal behavior changes.** Bounded by the differential corpus and
  the explain-every-diff rule above.

## Alternatives considered

- **Keep the hand port.** No new dependencies, but it is the code that
  keeps producing this bug class; every fix re-derives upstream semantics
  from decompiles.
- **Parse the full binary in Elixir, no NIF.** Trades the weld/grid code
  for an equally hand-rolled BV-tree/link loader and still needs the query
  algorithms in Elixir — strictly worse than the current projection.
- **Partial adoption** (native A*, Elixir funnel). The funnel is where the
  hardest bugs live; rejected.

## Open questions

- Set/key naming for the raw bytes (`navmesh_bin` vs a field on the
  existing document).
- Rust bindings crate vs vendoring upstream C (decide in Phase 1 by
  maintenance status of the bindings).
- When to retire the ETF projection (Phase 4 default: one release after
  cutover).
