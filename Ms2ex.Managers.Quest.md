# `Ms2ex.Managers.Quest`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/quest.ex#L1)

GenServer to manage quest state for a character.

This module handles quest state, progression tracking, condition checking,
quest completion, and reward distribution.

# `abandon`

Abandons a quest for a character.

# `can_complete?`

Checks if a character can complete a specific quest.

# `can_start?`

Checks if a character can start a specific quest.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `complete`

Completes a quest for a character.

# `dispatch`

Moves the character to a quest's dispatch destination (the "do you want to
travel?" prompt from quest dialogues).

# `expire_quests`

Removes the given quests from the character (expiration sweep from the
client) and drops their persisted rows.

# `get_all_quests`

Get all quests for a character, including both character-specific and account quests.
Returns a tuple of {account_quests, character_quests}.

# `get_available_quests`

Gets quests available from a specific NPC.

# `get_quest`

Get a specific quest by ID.

# `get_state`

Gets the current state of the quest manager.

# `go_to_npc`

Moves the character to a started quest's go-to-npc destination map.

# `load_quests`

Loads all quests for a character and sends to client.

# `start`

Starts a new quest for a character.

# `start_link`

Starts a quest manager for a character.

# `update_conditions`

Updates quest conditions based on character actions.

# `update_tracking`

Updates tracking status for a quest.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
