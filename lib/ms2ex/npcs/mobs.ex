defmodule Ms2ex.Mobs do
  alias Ms2ex.{CharacterManager, Inventory, Metadata, Packets}

  import Ms2ex.Field, only: [broadcast: 2]

  def respawn_mob(mob) do
    fields = Map.take(mob, [:is_boss?, :respawn, :spawn])
    meta = Metadata.Npcs.get(mob.id)

    mob
    |> Map.merge(meta)
    |> Map.merge(fields)
  end

  def process_death(character, mob) do
    reward_exp(character, mob)
    add_mob_loots(character, mob)
  end

  # TODO get list of items dropped
  defp add_mob_loots(character, mob) do
    item_ids = []

    Enum.each(item_ids, fn id ->
      item = %Inventory.Item{item_id: id}

      case Metadata.Items.load(item) do
        %{metadata: nil} ->
          :ok

        item ->
          item = Map.put(item, :position, mob.position)
          item = Map.put(item, :character_object_id, character.object_id)
          send(self(), {:add_item, item})
      end
    end)
  end

  defp reward_exp(character, mob) do
    # TODO adjust EXP formula
    exp_gained = trunc(mob.stats.hp.total / 10)
    old_lvl = character.level

    {:ok, character} = Ms2ex.Experience.maybe_add_exp(character, exp_gained)
    CharacterManager.update(character)

    if old_lvl != character.level do
      broadcast(self(), Packets.LevelUp.bytes(character))
    end

    exp_packet = Packets.Experience.bytes(exp_gained, character.exp, character.rest_exp)
    send(self(), {:push, character.id, exp_packet})
  end
end
