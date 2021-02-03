defmodule Ms2ex.Commands do
  alias Ms2ex.{Character, Characters, Field, Inventory, Metadata, Net, Packets, World}

  import Net.Session, only: [push: 2, push_notice: 3]

  def handle(["item" | ids], character, session) do
    Enum.reduce(ids, session, fn item_id, session ->
      with {item_id, _} <- Integer.parse(item_id),
           {:ok, meta} <- Metadata.Items.lookup(item_id) do
        item = %Inventory.Item{item_id: item_id, metadata: meta}
        add_item(character, item, session)
      else
        _ ->
          push_notice(session, character, "Invalid Item: #{item_id}")
      end
    end)
  end

  def handle(["level", level], character, session) do
    with {level, _} <- Integer.parse(level) do
      level = if level > Character.max_level(), do: Character.max_level(), else: level
      {:ok, character} = Characters.update(character, %{level: level})
      World.update_character(session.world, character)
      Field.broadcast(character, Packets.LevelUp.bytes(character, level))
      push(session, Packets.Experience.bytes(0, 0, 0))
    else
      _ ->
        push_notice(session, character, "Invalid Level: #{level}")
    end
  end

  def handle(["map", map_id], character, session) do
    with {map_id, _} <- Integer.parse(map_id),
         {:ok, map} <- Metadata.Maps.lookup(map_id) do
      spawn = List.first(map.spawns)
      Field.change_field(character, session, map_id, spawn.coord, spawn.rotation)
    else
      _ ->
        push_notice(session, character, "Invalid Map: #{map_id}")
    end
  end

  # def handle(["teleport", target_name], character, session) do
  #   with {:ok, target} <- Registries.Characters.lookup_by_name(target_name),
  #        {:ok, map} <- Metadata.Maps.lookup(target.map_id),
  #        {:ok, auth_data} = Registries.Sessions.lookup(session.account.id) do
  #     spawn = List.first(map.spawns)
  #     Field.change_field(character, session, map.id, spawn.coord, spawn.rotation)
  #     push(session, Packets.GameToGame.bytes(target.channel_id, target.map_id, auth_data))
  #   else
  #     _ ->
  #       push_notice(session, character, "Unable to teleport to character: #{target_name}")
  #   end
  # end

  def handle(args, character, session) do
    IO.inspect(args)
    push_notice(session, character, "Command not found")
  end

  defp add_item(character, item, session) do
    case Inventory.add_item(character, item) do
      {:ok, result} -> push(session, Packets.InventoryItem.add_item(result))
      _ -> session
    end
  end
end
