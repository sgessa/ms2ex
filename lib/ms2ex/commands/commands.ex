defmodule Ms2ex.Commands do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Constants
  alias Ms2ex.Types

  import Net.SenderSession, only: [push: 2, push_notice: 3]

  def handle(["heal"], character, session) do
    max_hp = character.stats.health_max
    Managers.Character.cast(character, {:increase_stats, [health: max_hp]})
    session
  end

  def handle(["hp", amount], character, session) do
    case Integer.parse(amount) do
      {amount, _} ->
        Managers.Character.cast(character, {:set_stat, :health, amount})
        session

      _ ->
        push_notice(session, character, "Invalid HP: #{amount}")
    end
  end

  def handle(["freecam" | args], _character, session) do
    toggled = List.first(args) != "off"

    if toggled do
      push(session, Packets.FieldProperty.add(:photo_studio))
    else
      push(session, Packets.FieldProperty.remove(:photo_studio))
    end
  end

  # !item 13160311           (rarity from the item's constant option)
  # !item 20300012 10        (10 potions)
  # !item 13160311 1 5       (1 weapon, rarity 5)
  def handle(["item", item_id | opts], character, session) do
    {qty, rarity} = parse_item_opts(opts)

    with {item_id, _} <- Integer.parse(item_id),
         metadata when not is_nil(metadata) <- Storage.get(:item, item_id) do
      item =
        Context.Items.init(item_id, %{
          rarity: rarity || resolve_rarity(metadata),
          amount: qty,
          transfer_flags: [:split, :trade]
        })

      {:ok, {_, item} = result} = Context.Inventory.add_item(character, item)

      session
      |> push(Packets.InventoryItem.add_item(result, character))
      |> push(Packets.InventoryItem.mark_item_new(item))
    else
      _ -> push_notice(session, character, "Invalid Item: #{item_id}")
    end
  end

  def handle(["level", level], character, session) do
    case Integer.parse(level) do
      {level, _} ->
        level = min(level, Constants.get(:character_max_level))
        {:ok, _character} = Managers.Character.set_level(character, level)
        push(session, Packets.Experience.bytes(0, 0, 0))

      _ ->
        push_notice(session, character, "Invalid Level: #{level}")
    end
  end

  def handle(["map", map_id], character, session) do
    case Integer.parse(map_id) do
      {map_id, _} -> Context.Field.change_field(character, map_id)
      _ -> push_notice(session, character, "Invalid Map: #{map_id}")
    end
  end

  def handle(["boss", mob_id], character, session) do
    with {mob_id, _} <- Integer.parse(mob_id),
         metadata when not is_nil(metadata) <- Storage.Npcs.get_meta(mob_id),
         %Types.Npc{} = npc <- Types.Npc.new(%{id: mob_id, metadata: metadata}) do
      Context.Field.add_mob(character, %{npc | boss?: true})
      session
    else
      _ ->
        push_notice(session, character, "Invalid Mob: #{mob_id}")
    end
  end

  def handle(["mob", mob_id], character, session) do
    with {mob_id, _} <- Integer.parse(mob_id),
         metadata when not is_nil(metadata) <- Storage.Npcs.get_meta(mob_id),
         %Types.Npc{} = npc <- Types.Npc.new(%{id: mob_id, metadata: metadata}) do
      Context.Field.add_mob(character, npc)
      session
    else
      _ ->
        push_notice(session, character, "Invalid Mob: #{mob_id}")
    end
  end

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

  defp parse_item_opts(opts) do
    case Enum.map(opts, &Integer.parse/1) do
      [{qty, _}, {rarity, _}] -> {qty, rarity}
      [{qty, _}] -> {qty, nil}
      _ -> {1, nil}
    end
  end

  defp resolve_rarity(%{option: %{constant_id: constant}}) when constant in 1..6, do: constant
  defp resolve_rarity(_), do: 1
end
