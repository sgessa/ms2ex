# Trigger-script runtime

Status: the xblock trigger scripts run on every map that ships them. Each
script is a state machine ticking at 100ms: on-enter actions run, then
conditions evaluate in document order — the first true condition runs its
inline actions and transitions. Unimplemented actions warn in the server log
so coverage gaps surface per map.

## Conditions

user_detected (job-gated, padded boxes), monster_dead, quest_user_detected
(wanted states: 1 started-not-completable, 2 completable, 3 completed),
npc_detected (a story npc's spawn point standing inside a box),
object_interacted (an interact object — matched by table id — sitting in
the wanted state: 0 normal, 1 reactable, 2 hidden; e.g. the tutorial car
flip once boarded), widget_condition (Guide/SceneMovie), user_value
(script variables set via set_user_value), wait_tick (against state
entry), negate, always.

Int-list arguments accept single ids, comma lists and inclusive ranges
(`5001-5025` expands to every id).

## Actions

- scene/UI: set_mesh, set_effect, set_cinematic_ui (letterbox / fade / wipes
  / opening black screen), set_onetime_effect, select_camera (map camera
  vantage on/off), select_camera_path / reset_camera, add_cinematic_talk /
  remove_cinematic_talk, set_dialogue (player/npc speech balloons),
  show_caption, show/hide_guide_summary (held during cinematics and scripted
  path moves, flushed when control returns), set_skip + set_scene_skip +
  skip-cutscene handling, set_time_scale (field tick-rate ramp),
  set_ambient_light (field light tint), set_event_ui (round/script/countdown
  overlays scoped to trigger boxes, `!` negation, box 0 = everyone)
- actors: spawn_monster / destroy_monster (mob and friendly spawns) — event
  spawn points load dormant and appear only when a script summons them; all
  other spawns load with the field per their on-create flag, so plain quest
  npcs coexist with scripted maps, set_agent (agent figure visibility),
  set_actor (actor figure visibility + animation sequence),
  move_npc (patrol walk, stays at the last waypoint),
  set_npc_emotion_loop / set_npc_emotion_sequence,
  set_pc_emotion_loop / set_pc_emotion_sequence, move_user (same-map
  teleport via navmesh validation; cross-map field change where the
  destination portal id is a hint — falls back to its return portal or
  default spawn), move_user_path (invisible follow-dummy walks the patrol,
  the client walks the player behind it), create_item (fixed-position,
  unowned field item from a named id or the spawn point's drop box)
- world: set_portal, set_ladder (ladder visibility + climb-in animation —
  ladders are not projected, the update reaches the client by id), guide_event,
  create_widget / widget_action, play_scene_movie,
  play_system_sound_in_box, set_breakable / set_visible_breakable_object
  (cube breakables and scene-actor breakables — the actor kind is the
  client-side moving platforms such as the chase carts; each show stamps a
  base tick so a platform's shuttle restarts from its start instead of
  resuming mid-cycle),
  set_interact_object (flips the field's interact state — server state and
  client update together; scripts rely on object_interacted reading the same
  state a player's react sets), set_user_value, add/remove_buff, set_skill (trigger
  skill zones — the falling rocks of the tutorial chase. Enable spawns a
  fire-count-limited zone announced to clients and owned by the field:
  each fire applies the zone skill's attack to players standing inside —
  max-health share, constant value — through the shared stats path, plus
  the skill's effect as a buff, and broadcasts a tile damage record with
  the push direction. Disable removes every active zone for the trigger
  id), set_achievement (a condition event for players in a box feeding the
  quest and achievement pipelines — completes trigger-gated main quests)

## Still missing

- camera cutscene fidelity: paths play, but the revert behavior diverges
  (camera keeps drifting after the spline; player movement is not locked
  during scripted cameras). Load-time camera registration deliberately
  arrives invisible (a visible entry activates the view client-side,
  stranding relogs outside the intro)
- balloon-family follow-ups: remove_balloon_talk and dialogue delay_tick
  scheduling (the client applies the delay itself, so wait_tick-gated
  scripts are unaffected)
- server-side trigger-skill-zone ticks (zone damage on entities) — map
  cube-skill zones (boost lanes, poison water, lava) now tick and apply
  their effect to players inside, so the remaining gap is narrow
