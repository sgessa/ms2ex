defmodule Ms2ex.LoginHandlers.CharacterManagement do
  alias Ms2ex.{
    Character,
    Context,
    Equips,
    Hair,
    Inventory,
    Items,
    ItemColor,
    ProtoMetadata,
    Net,
    Packets,
    Repo,
    SessionManager,
    SkinColor
  }

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  # Login
  def handle(<<0x0, packet::bytes>>, session) do
    handle_login(packet, session)
  end

  # Create Character
  def handle(<<0x1, packet::bytes>>, session) do
    handle_create(packet, session)
  end

  # Delete Character
  def handle(<<0x2, packet::bytes>>, session) do
    handle_delete(packet, session)
  end

  defp handle_login(packet, %{account: account} = session) do
    {char_id, _packet} = get_long(packet)

    case Context.Characters.get(account, char_id) do
      %Character{} ->
        auth_data = %{token_a: Ms2ex.generate_int(), token_b: Ms2ex.generate_int()}
        register_session(account.id, char_id, auth_data)
        push(session, Packets.LoginToGame.login(auth_data))

      _ ->
        session
    end
  end

  defp register_session(account_id, character_id, auth_data) do
    :ok =
      SessionManager.register(
        account_id,
        Map.merge(auth_data, %{account_id: account_id, character_id: character_id})
      )
  end

  defp handle_create(packet, session) do
    {gender, packet} = get_byte(packet)
    {job, packet} = get_short(packet)
    {name, packet} = get_ustring(packet)
    {skin_color, packet} = SkinColor.get_skin_color(packet)
    {_, packet} = get_short(packet)
    {equip_count, packet} = get_byte(packet)

    {equips, _packet} =
      Enum.reduce(0..equip_count, {[], packet}, fn
        0, acc ->
          acc

        _, {equips, packet} ->
          {equip, packet} = get_equip(packet)
          {equips ++ [equip], packet}
      end)

    attrs = %{
      gender: gender,
      job: ProtoMetadata.Job.key(job),
      map_id: 2_000_023,
      name: name,
      skin_color: skin_color
    }

    result =
      Repo.transaction(fn ->
        with {:ok, character} <- Context.Characters.create(session.account, attrs) do
          Enum.each(equips, fn {equip_slot, item} ->
            {:ok, {:create, item}} = Inventory.add_item(character, item)
            {:ok, _equip} = Equips.equip(item, equip_slot)
          end)

          equips = Equips.list(character)
          %{character | equips: equips}
        else
          error -> Repo.rollback(error)
        end
      end)

    case result do
      {:ok, character} ->
        session
        |> push(Packets.CharacterMaxCount.set_max(4, 6))
        |> push(Packets.CharacterList.append(character))

      _error ->
        push(session, Packets.CharacterCreate.name_taken())
    end
  end

  defp get_equip(packet) do
    {id, packet} = get_int(packet)
    {slot_name, packet} = get_ustring(packet)
    {color, packet} = ItemColor.get_item_color(packet)
    {_color_idx, packet} = get_int(packet)
    {attrs, packet} = get_item_attributes(packet, slot_name)

    attrs = Map.put(attrs, :color, color)
    item = Items.init(id, attrs)

    {{String.to_existing_atom(slot_name), item}, packet}
  end

  defp get_item_attributes(packet, "HR") do
    {hair, packet} = Hair.get_hair(packet)
    {%{data: hair}, packet}
  end

  defp get_item_attributes(packet, "FD") do
    {data, packet} = get_bytes(packet, 16)
    {%{data: data}, packet}
  end

  defp get_item_attributes(packet, _), do: {%{}, packet}

  defp handle_delete(packet, session) do
    {char_id, _packet} = get_long(packet)

    with %Character{} = character <- Context.Characters.get(session.account, char_id),
         {:ok, _} <- Context.Characters.delete(character) do
      characters = Context.Characters.list(session.account)

      session
      |> push(Packets.CharacterMaxCount.set_max(4, 6))
      |> push(Packets.CharacterList.start_list())
      |> push(Packets.CharacterList.add_entries(characters))
      |> push(Packets.CharacterList.end_list())
    else
      _ -> session
    end
  end
end
