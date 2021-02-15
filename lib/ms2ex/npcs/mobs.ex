defmodule Ms2ex.Mobs do
  alias Ms2ex.{Inventory, Metadata, Packets, World}

  import Ms2ex.Field, only: [broadcast: 2]

  def init_mob(mob, object_id) do
    mob
    |> set_default_hp()
    |> Map.put(:animation, 255)
    |> Map.put(:direction, mob.rotation.z * 10)
    |> Map.put(:object_id, object_id)
    |> Map.put(:position, mob.spawn)
  end

  def respawn_mob(mob) do
    fields = Map.take(mob, [:boss?, :respawn, :spawn])
    meta = Metadata.Npcs.get(mob.id)

    mob
    |> Map.merge(meta)
    |> Map.merge(fields)
  end

  defp set_default_hp(mob) do
    update_in(mob, [Access.key!(:stats), Access.key!(:hp), Access.key!(:max)], fn _ ->
      mob.stats.hp.total
    end)
  end

  def process_death(world, character, mob) do
    reward_exp(world, character, mob)
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

  # TODO implement LEVEL UP
  defp reward_exp(world, character, mob) do
    # TODO adjust EXP formula
    exp_gained = trunc(mob.stats.hp.total / 10)
    old_lvl = character.level

    {:ok, character} = Ms2ex.Experience.maybe_add_exp(character, exp_gained)
    World.update_character(world, character)

    if old_lvl != character.level do
      broadcast(self(), Packets.LevelUp.bytes(character))
    end

    exp_packet = Packets.Experience.bytes(exp_gained, character.exp, character.rest_exp)
    send(self(), {:push, character.id, exp_packet})
  end
end
