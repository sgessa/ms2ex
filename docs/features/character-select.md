# Character selection

The character-selection screen runs on the world login session. The client
authenticates (`RESPONSE_LOGIN`), receives the character list, and then
manages characters through `CHARACTER_MANAGEMENT` requests until it selects
one and migrates to the game server.

## Character list

The list is streamed as a packet set: `CharacterMaxCount` (unlocked/total
slots), `CharacterList` `start_list`, one `CharacterList` `add_entries`
packet holding every entry, then `CharacterList` `end_list`. The same set is
sent after login, after `RESPONSE_SERVER_ENTER` (returning from the game
server), and after creating a character.

`CharacterList` modes:

| Mode | Name          | Payload                                        |
| ---- | ------------- | ---------------------------------------------- |
| 0x0  | add entries   | byte count, then one entry per character       |
| 0x1  | append entry  | one entry (sent after character creation)      |
| 0x2  | delete entry  | error int, character id long                   |
| 0x3  | start list    | —                                              |
| 0x4  | end list      | bool                                           |
| 0x5  | begin delete  | character id long, error int, delete time long |
| 0x6  | cancel delete | character id long, error int                   |

Each entry serializes the character (`CharacterList.put_character/4`, shared
with party/group-chat/field packets), the profile URL, the pending
`delete_time`, the equipped items, and badges.

## Management commands

`CHARACTER_MANAGEMENT` carries a command byte: `0x0` select, `0x1` create,
`0x2` delete, `0x3` cancel delete, `0x4` confirm delete. Delete and confirm
share the same flow (see
`Ms2ex.LoginHandlers.CharacterManagement`).

### Deletion state machine

Deletion is guarded by two server-table constants:
`character_destroy_division_level` (20) and
`character_destroy_wait_second` (86 400). Characters below the division
level are removed immediately; characters at or above it enter a deletion
wait that can still be cancelled.

1. Every request first validates the character: unread mail
   (`s_char_err_unread_mail`), guild leader (`s_char_err_guild_master`) and
   guild member (`s_char_err_guild`) block the deletion. Failures answer
   with a `delete_entry` packet carrying the error code (the client shows
   the matching message and stays on the list).
2. A pending deletion whose time has passed is finalized: the row is deleted
   and a `delete_entry` ack (error 0) tells the client to drop the entry.
3. A pending deletion still in the future is only re-acked with
   `begin_delete` + `s_char_err_next_delete_char_date`, so the client keeps
   its countdown.
4. A fresh request below the division level deletes immediately and acks
   with `delete_entry` (error 0).
5. A fresh request at or above the division level stores
   `delete_time = now + character_destroy_wait_second` on the character and
   acks with `begin_delete` (error 0). The character stays in the list; the
   entry's delete-time field drives the client's countdown display.
6. `cancel delete` clears `delete_time` and acks with `cancel_delete`
   (error 0), or answers `s_char_err_no_destroy_wait` when nothing is
   pending.

A `delete_entry`/`begin_delete`/`cancel_delete` ack is always sent — the
client's delete dialog only closes on it, so answering with a full list
re-send instead leaves the client's deletion flow stuck.

## Selection

Selecting a character (`0x0`) registers the session's auth tokens with the
session manager and answers with `LoginToGame`, handing the client over to
the game server.
