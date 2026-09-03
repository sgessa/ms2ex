# `Ms2ex.Managers.Quest.Requirements`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/managers/quest/requirements.ex#L1)

Functions for checking if quest requirements are met.

This module provides utilities to check various requirements for starting quests,
including level, job, gear score, and prerequisite quests.

# `can_start?`

Checks if a character can start a quest based on its metadata requirements.

## Parameters
  * `character` - The character attempting to start the quest
  * `metadata` - The quest metadata containing requirements
  * `state` - The current quest manager state

## Returns
  * `true` - Character meets all requirements
  * `false` - Character does not meet all requirements

---

*Consult [api-reference.md](api-reference.md) for complete listing*
