# `Ms2ex.Context.Fishing`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/context/fishing.ex#L1)

Pure fishing behaviour: water-tile reachability, fish selection, bite
timers and catch rolls, plus the session-map transitions.

Stateless by design — the session and album state live in
`Ms2ex.Managers.Fishing`, which turns these results into packets and
persistence.

# `available_fishes`

The fish that can bite on the given tile, given the active lure.

# `bite`

Drops the line: stores the tile, fish and bait state for the cast.

# `bite_timer`

The bite delay and whether the catch turns into a fight minigame: a bite
lands inside the bore window, a miss runs past it so the client times out.

# `clear_minigame`

The client lost the fight minigame; the bite stays but the game ends.

# `fishing_lure?`

True when the item's metadata marks a fishing lure.

# `guide_position`

The bobber position: one block above the water surface, on the reachable
tile closest to the player.

# `move_guide`

Tracks where the player dragged the bobber.

# `pick_weighted`

Picks the fish that bites, weighted by the box weights.

# `reachable_tiles`

The water tiles the player can fish into: the client only lets a player
fish into the quadrant they face, so the box in front of them is scanned
for surface water.

# `record_catch`

```elixir
@spec record_catch(map(), integer(), integer(), boolean()) ::
  {map(), map(), boolean()}
```

Records a catch in the album. Returns the updated album, the entry and
whether this was the first catch of that kind.

# `roll_size`

The caught fish's size.

# `select_bait`

Keeps the selected bait for the active session.

# `session_tiles`

Indexes the reachable tiles by their block cell.

# `tile_at`

The indexed tile at the given position's block cell, if any.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
