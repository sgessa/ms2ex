defmodule Ms2ex.Commands do
  alias Ms2ex.{
    Character,
    Characters,
    CharacterManager,
    Field,
    Inventory,
    Metadata,
    Net,
    Packets,
    Wallets
  }

  import Net.Session, only: [push: 2, push_notice: 3]

  def handle(["heal"], %{stats: stats} = character, session) do
    max_hp = stats.hp_cur
    stats = stats |> Map.delete(:__struct__) |> Map.put(:current_hp_min, max_hp)
    {:ok, character} = Characters.update(character, %{stats: stats})
    CharacterManager.update(character)
    push(session, Packets.Stats.set_character_stats(character))
  end

  def handle(["item" | ids], character, session) do
    Enum.reduce(ids, session, fn item_id, session ->
      with {item_id, _} <- Integer.parse(item_id),
           {:ok, meta} <- Metadata.Items.lookup(item_id) do
        flags = Ms2ex.TransferFlags.set([:splittable, :tradeable])
        item = %Inventory.Item{item_id: item_id, transfer_flags: flags, metadata: meta}
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
      {:ok, character} = Characters.update(character, %{exp: 0, level: level})
      CharacterManager.update(character)
      Field.broadcast(character, Packets.LevelUp.bytes(character))
      push(session, Packets.Experience.bytes(0, 0, 0))
    else
      _ ->
        push_notice(session, character, "Invalid Level: #{level}")
    end
  end

  def handle(["map", field_id], character, session) do
    with {field_id, _} <- Integer.parse(field_id) do
      Field.change_field(character, session, field_id)
    else
      _ ->
        push_notice(session, character, "Invalid Map: #{field_id}")
    end
  end

  def handle(["boss", mob_id], character, session) do
    with {mob_id, _} <- Integer.parse(mob_id),
         {:ok, mob} <- Metadata.Npcs.lookup(mob_id) do
      Field.add_mob(character, %{mob | is_boss?: true, respawn: false, spawn: character.position})
      session
    else
      _ ->
        push_notice(session, character, "Invalid Mob: #{mob_id}")
    end
  end

  def handle(["mob", mob_id], character, session) do
    with {mob_id, _} <- Integer.parse(mob_id),
         {:ok, mob} <- Metadata.Npcs.lookup(mob_id) do
      Field.add_mob(character, %{mob | respawn: false, spawn: character.position})
      session
    else
      _ ->
        push_notice(session, character, "Invalid Mob: #{mob_id}")
    end
  end

  def handle([currency, amount], character, session) when currency in ["merets", "mesos"] do
    currency = String.to_existing_atom(currency)

    with {amount, _} <- Integer.parse(amount),
         {:ok, wallet} <- Wallets.update(character, currency, amount) do
      push(session, Packets.Wallet.update(wallet, currency))
    else
      _ ->
        push_notice(session, character, "Invalid amount: #{amount}")
    end
  end

  def handle(["summon", target_name], character, session) do
    case CharacterManager.lookup_by_name(target_name) do
      {:ok, target} ->
        cond do
          character.channel_id != target.channel_id ->
            push_notice(session, character, "Character is in Channel #{target.channel_id}")

          character.field_id == target.field_id ->
            coord = character.position
            send(target.session_pid, {:push, Packets.MoveCharacter.bytes(target, coord)})
            session

          true ->
            target = Map.put(target, :update_position, character.position)
            CharacterManager.update(target)
            send(target.session_pid, {:summon, target, character.field_id})
            session
        end

      _ ->
        push_notice(session, character, "Unable to summon character: #{target_name}")
    end
  end

  def handle(["teleport", target_name], character, session) do
    case CharacterManager.lookup_by_name(target_name) do
      {:ok, target} ->
        cond do
          character.channel_id != target.channel_id ->
            push_notice(session, character, "Character is in Channel #{target.channel_id}")

          character.field_id == target.field_id ->
            push(session, Packets.MoveCharacter.bytes(character, target.position))

          true ->
            character = Map.put(character, :update_position, target.position)
            CharacterManager.update(character)
            Field.change_field(character, session, target.field_id)
        end

      _ ->
        push_notice(session, character, "Unable to teleport to character: #{target_name}")
    end
  end

  def handle(_args, character, session) do
    push_notice(session, character, "Command not found")
  end

  defp add_item(character, item, session) do
    case Inventory.add_item(character, item) do
      {:ok, result} -> push(session, Packets.InventoryItem.add_item(result))
      _ -> session
    end
  end
end
