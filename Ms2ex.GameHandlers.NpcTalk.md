# `Ms2ex.GameHandlers.NpcTalk`
[🔗](https://github.com/sgessa/ms2ex/blob/main/lib/ms2ex/handlers/game/npc_talk.ex#L1)

NPC interaction flow (talk + quest selection).

Flow: `Quest.talk` announces the quest list, `NpcTalk.respond` opens the
dialogue bound to the npc (first available quest's script state when quests
exist), and picking a quest from the list re-enters the dialogue via
`NpcTalk.continue` for that quest's script state (100s accept / 200s
progress / 300s complete).

# `handle`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
