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
- `Managers.Field.instance_id/1` allocates a fresh unique id per call
  for `solo` maps and returns 0 (shared) for everything else.
- Relog parity: instanced maps are never persisted as the character's
  current map (`response_field_enter` skips the `map_id` update), so a
  relog returns the player to the map the instance was entered from.
  In-memory the character still carries the instance map, so quest
  conditions and guild map updates keep working inside it.

## Reference parity notes

- `InstanceType` values from the game table: solo, channelScale,
  massiveEvent, ugcMap, GameMaker, GuildEvent, DungeonLobby, GuildHouse,
  WeddingHall, FieldWar, ... — the docs' `:type` atom mirrors the table.
- The reference keys fields `(MapId, RoomId)` with a global id counter
  and creates a fresh room per entry for the default (solo) case.

## Still missing

- party follow: joining a leader's existing instance (carry the
  leader's instance id instead of allocating)
- other instance types: dungeon lobbies/rooms, guild houses/events,
  wedding halls, massive events with room pools (`pool_count`)
- `max_count` caps on channel-scale instances
- `save_field` (persist and restore a solo instance's state across
  sessions) and `npc_stat_factor_id` scaling
