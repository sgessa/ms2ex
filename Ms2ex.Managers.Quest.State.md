# `Ms2ex.Managers.Quest.State`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/quest/state.ex#L1)

Helper functions for managing quest state.

This module provides utilities to create, update, and manage quests in the state.
It handles operations like quest creation, completion, abandonment, and tracking.

# `abandon_quest`

Updates a quest's state to abandoned.

## Parameters
  * `quest` - The quest to abandon

## Returns
  * `{:ok, updated_quest}` - Successfully abandoned quest
  * `{:error, changeset}` - Failed to update quest

# `add_quest_to_state`

Adds or updates a quest in the state map.

## Parameters
  * `quest` - The quest to add/update
  * `state` - The current state map

## Returns
  * Updated state map with the quest added/updated

# `complete_quest`

Updates a quest's state to completed.

## Parameters
  * `quest` - The quest to complete

## Returns
  * `{:ok, updated_quest}` - Successfully completed quest
  * `{:error, changeset}` - Failed to update quest

# `create_quest`

Creates a new quest for a character.

## Parameters
  * `character` - The character struct
  * `quest_metadata` - The metadata for the quest to create

## Returns
  * `{:ok, quest}` - Successfully created quest
  * `{:error, changeset}` - Failed to create quest

# `get_active_quests`

Gets all active quests from the state.

## Parameters
  * `state` - The current state map

## Returns
  * List of all active quests (both account and character quests)

# `get_quest_from_state`

Gets a specific quest from the state.

## Parameters
  * `quest_id` - ID of the quest to retrieve
  * `state` - The current state map

## Returns
  * Quest struct if found, nil otherwise

# `remove_quest_from_state`

Remove a quest from the state map.

## Parameters
  * `quest` - The quest to remove
  * `state` - The current state map

## Returns
  * Updated state map with the quest removed

# `update_tracking`

Updates the tracking status of a quest.

## Parameters
  * `quest` - The quest to update
  * `tracking` - Boolean indicating whether to track the quest

## Returns
  * `{:ok, updated_quest}` - Successfully updated quest
  * `{:error, changeset}` - Failed to update quest

---

*Consult [api-reference.md](api-reference.md) for complete listing*
