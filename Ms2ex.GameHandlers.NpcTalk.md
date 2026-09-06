# `Ms2ex.GameHandlers.NpcTalk`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/handlers/game/npc_talk.ex#L1)

NPC interaction flow (talk + quest selection).

Flow: `Quest.talk` announces the quest list, `NpcTalk.respond` opens the
dialogue. When the npc offers a quest AND has its own talk script, the
select script opens the choice menu first (quest vs plain talk); picking
a side re-enters the dialogue via `NpcTalk.continue` for the quest's
script state (100s accept / 200s progress / 300s complete) or the npc's
talk script.

# `handle`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
