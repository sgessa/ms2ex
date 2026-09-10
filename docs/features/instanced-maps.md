# Instanced maps

Status: instancing is metadata-driven. The instance-field table
(`server.instancefield.xml`, projected from the game's
`table/Server/InstanceField.xml`) lists maps that must not be shared:
`solo` maps (tutorials, quest instances) allocate a private field per
entry; `channel_scale` maps keep one shared field per channel; maps
absent from the table are ordinary shared fields.

## How it works

- `Storage.Tables.InstanceFields` exposes the per-map docs (`:type`,
  `:instance_id`, `:pool_count`, `:max_count`, `:save_field`,
  `:npc_stat_factor_id`), `instanced?/1` and `solo?/1`.
- Field process names carry the instance id
  (`Managers.Field.field_name/3`): two players entering the same `solo`
  tutorial map land in two independent field processes — own npcs,
  own trigger machines, own drops.
- The instance id is allocated once per transition and carried on the
  character: `change_field` stamps it into `change_map`,
  `Managers.Field.assign_instance/1` binds it before the field subscribe,
  and `enter/1` reuses it — a repeated field enter for the same visit
  rejoins the same field instead of spawning another one.
- The field's PubSub topic carries the instance id too (`init/3`-built
  via `field_name/3`), so two solo instances of the same map never hear
  each other's packets; session-side topic helpers read
  `character.field_instance`.
- `Managers.Field.instance_id/1` allocates a fresh unique id for `solo`
  maps and returns 0 (shared) for everything else.
- Return maps: when a field change enters a map that declares an
  `enter_return_id`, the hub is persisted instead of the map itself (the
  reference's logout reset, collapsed from its 3-deep return-map stack —
  ms2ex deliberately skips that stack's stale-entry quirk). The cube
  return-map packet advertises the same target.
- Relog behavior: the current map persists through instanced maps too —
  the reference's `SpawnPlayer` sets `Character.MapId` on every entry and
  only maps that push a return-map (`InstanceType.none` with an
  `EnterReturnId`, or `SaveField` maps) reset it at logout. A relog
  mid-tutorial therefore lands in a fresh instance of the same stage.

## Reference parity notes

- `InstanceType` values from the game table: solo, channelScale,
  massiveEvent, ugcMap, GameMaker, GuildEvent, DungeonLobby, GuildHouse,
  WeddingHall, FieldWar, ... — the docs' `:type` atom mirrors the table.
- The reference keys fields `(MapId, RoomId)` with a global id counter
  and creates a fresh room per entry for the default (solo) case.

- instanced fields stop immediately when they empty out (nothing can
  rejoin them); shared fields linger five minutes for returning players
  (see `field-manager.md`)

## Still missing

- party follow: joining a leader's existing instance (carry the
  leader's instance id instead of allocating)
- OOB recovery during scripted sequences: `user_sync`'s out-of-bounds
  teleport still runs while a cinematic or scripted path move controls
  the player (same gap as trigger-runtime's "movement is not locked"
  note) — guard it with the field's guide-hold state
- navmesh coverage: scripted maps whose xblock has no navmesh skip the
  move_user walkable-ground check (see `navmesh.md` — the class-intro
  chain is covered, the rest is flag-by-flag)
- other instance types: dungeon lobbies/rooms, guild houses/events,
  wedding halls, massive events with room pools (`pool_count`)
- `max_count` caps on channel-scale instances
- `save_field` (persist and restore a solo instance's state across
  sessions) and `npc_stat_factor_id` scaling
- entry gating: `backup_source_portal` and `open_type`/`open_value` are
  projected but unused
