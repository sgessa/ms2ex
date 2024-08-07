defmodule Ms2ex.Commands do
  alias Ms2ex.{
    Managers,
    Context,
    Net,
    Packets,
    Storage,
    Constants
  }

  import Net.SenderSession, only: [push: 2, push_notice: 3]

  def handle(["heal"], character, session) do
    max_hp = character.stats.health_max
    Managers.Character.increase_stat(character, :health, max_hp)
    session
  end

  def handle(["freecam" | args], _character, session) do
    toggled = List.first(args) != "off"

    if toggled do
      push(session, Packets.FieldProperty.add(:photo_studio))
    else
      push(session, Packets.FieldProperty.remove(:photo_studio))
    end
  end

  # !item 5 13160311
  def handle(["item" | args], character, session) do
    [rarity | ids] = args

    Enum.reduce(ids, session, fn item_id, session ->
      case Storage.get(:item, item_id) do
        nil -> push_notice(session, character, "Invalid Item: #{item_id}")
        _metadata -> add_item(character, item_id, rarity, session)
      end
    end)
  end

  def handle(["level", level], character, session) do
    with {level, _} <- Integer.parse(level) do
      level = min(level, Constants.get(:character_max_level))
      {:ok, character} = Context.Characters.update(character, %{exp: 0, level: level})
      Managers.Character.update(character)

      Context.Field.broadcast(character, Packets.LevelUp.bytes(character))
      push(session, Packets.Experience.bytes(0, 0, 0))
    else
      _ ->
        push_notice(session, character, "Invalid Level: #{level}")
    end
  end

  def handle(["map", map_id], character, session) do
    with {map_id, _} <- Integer.parse(map_id) do
      Context.Field.change_field(character, map_id)
    else
      _ ->
        push_notice(session, character, "Invalid Map: #{map_id}")
    end
  end

  # def handle(["boss", mob_id], character, session) do
  #   with {mob_id, _} <- Integer.parse(mob_id),
  #        {:ok, npc} <- ProtoMetadata.Npcs.lookup(mob_id) do
  #     npc = Map.merge(npc, %{boss?: true, respawnable?: false})
  #     Context.Field.add_mob(character, npc)
  #     session
  #   else
  #     _ ->
  #       push_notice(session, character, "Invalid Mob: #{mob_id}")
  #   end
  # end

  # def handle(["mob", mob_id], character, session) do
  #   with {mob_id, _} <- Integer.parse(mob_id),
  #        metadata when not is_nil(metadata) <- Storage.Npcs.get_meta(mob_id) do
  #     Context.Field.add_mob(character, npc)
  #     session
  #   else
  #     _ ->
  #       push_notice(session, character, "Invalid Mob: #{mob_id}")
  #   end
  # end

  def handle([currency, amount], character, session) when currency in ["merets", "mesos"] do
    currency = String.to_existing_atom(currency)

    with {amount, _} <- Integer.parse(amount),
         {:ok, wallet} <- Context.Wallets.update(character, currency, amount) do
      push(session, Packets.Wallet.update(wallet, currency))
    else
      _ ->
        push_notice(session, character, "Invalid amount: #{amount}")
    end
  end

  def handle(["summon", target_name], character, session) do
    case Managers.Character.lookup_by_name(target_name) do
      {:ok, target} ->
        cond do
          character.channel_id != target.channel_id ->
            push_notice(session, character, "Character is in Channel #{target.channel_id}")

          character.map_id == target.map_id ->
            coord = character.position
            push(target, Packets.MoveCharacter.bytes(target, coord))

          true ->
            target = Map.put(target, :update_position, character.position)
            Managers.Character.update(target)
            send(target.sender_session_pid, {:summon, target, character.map_id})
        end

      _ ->
        push_notice(session, character, "Unable to summon character: #{target_name}")
    end
  end

  def handle(["teleport", target_name], character, session) do
    case Managers.Character.lookup_by_name(target_name) do
      {:ok, target} ->
        cond do
          character.channel_id != target.channel_id ->
            push_notice(session, character, "Character is in Channel #{target.channel_id}")

          character.map_id == target.map_id ->
            push(session, Packets.MoveCharacter.bytes(character, target.position))

          true ->
            character = Map.put(character, :update_position, target.position)
            Managers.Character.update(character)
            Context.Field.change_field(character, target.map_id)
        end

      _ ->
        push_notice(session, character, "Unable to teleport to character: #{target_name}")
    end
  end

  def handle(_args, character, session) do
    push_notice(session, character, "Command not found")
  end

  defp add_item(character, item_id, rarity, session) do
    flags = Ms2ex.TransferFlags.set([:splittable, :tradeable])

    with {item_id, _} <- Integer.parse(item_id),
         {rarity, _} <- Integer.parse(rarity),
         item = Context.Items.init(item_id, %{rarity: rarity, transfer_flags: flags}),
         {:ok, {_, item} = result} <- Context.Inventory.add_item(character, item) do
      session
      |> push(Packets.InventoryItem.add_item(result))
      |> push(Packets.InventoryItem.mark_item_new(item))
    end
  end
end
