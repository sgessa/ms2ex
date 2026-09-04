defmodule Ms2ex.Managers.Character.Experience do
  alias Ms2ex.Constants
  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]

  def earn_exp(character, amount) do
    old_lvl = character.level
    cooldowns = Map.get(character, :skill_cooldowns, %{})
    {:ok, character} = Context.Experience.maybe_add_exp(character, amount)
    character = refresh_level(character, old_lvl)
    push(character, Packets.Experience.bytes(amount, character.exp, character.rest_exp))
    Map.put(character, :skill_cooldowns, cooldowns)
  end

  def set_level(character, level) do
    level = level |> max(1) |> min(Constants.get(:character_max_level))
    old_level = character.level
    {:ok, character} = Context.Characters.update(character, %{exp: 0, level: level})
    {:ok, refresh_level(character, old_level)}
  end

  def refresh_level(character, old_level) do
    if old_level != character.level do
      equips = Managers.Inventory.list_equips(character)
      {character, _equipment_stats} = Context.CharacterStats.apply(character, equips)
      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
      Context.Field.broadcast_stats(character)

      # level-reach quest conditions; the level_up code param carries the job id
      Managers.Quest.update_conditions(character.id, :level, 1, "", character.level, "", 0)

      Managers.Quest.update_conditions(
        character.id,
        :level_up,
        1,
        "",
        character.level,
        "",
        Enums.Job.get_value(character.job)
      )

      character
    else
      character
    end
  end
end
