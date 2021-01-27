defmodule Ms2ex.LoginHandlers.CharacterManagement do
  alias Ms2ex.{
    Character,
    Characters,
    Equips,
    Inventory,
    ItemColor,
    Net,
    Packets,
    Registries,
    SkinColor,
    Users
  }

  alias Inventory.Item

  import Packets.PacketReader
  import Net.SessionHandler, only: [push: 2]

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
    character = Enum.find(account.characters, &(&1.id == char_id))

    auth_data = %{token_a: gen_auth_token(), token_b: gen_auth_token()}
    register_session(account, character, auth_data)

    session
    |> Map.put(:character, character)
    |> push(Packets.LoginToGame.login(auth_data))
  end

  # Register session data in the global registry.
  # This allows us to lookup the session PID from any server.
  defp register_session(account, character, auth_data) do
    :ok =
      Registries.Sessions.register(
        account.id,
        Map.merge(auth_data, %{account_id: account.id, character_id: character.id})
      )
  end

  defp gen_auth_token() do
    floor(:rand.uniform() * floor(:math.pow(2, 31)))
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
      equipment: %{},
      gender: gender,
      job: job,
      map_id: 52_000_065,
      name: name,
      position: {-800, 600, 500},
      skin_color: skin_color
    }

    with {:ok, character} <- Characters.create(session.account, attrs) do
      Enum.each(equips, fn item ->
        {:ok, {:create, item}} = Inventory.add_item(character, item)
        {:ok, _equip} = Equips.set_equip(character, item)
      end)

      character = Characters.load_equips(character, force: true)
      characters = session.account.characters ++ [character]
      account = %{session.account | characters: characters}

      session
      |> Map.put(:account, account)
      |> push(Packets.CharacterMaxCount.set_max(4, 6))
      |> push(Packets.CharacterList.append(character))
    else
      error ->
        IO.inspect(error)

        session
        |> push(Packets.CharacterCreate.name_taken())
    end
  end

  defp get_equip(packet) do
    {id, packet} = get_int(packet)
    {slot_name, packet} = get_ustring(packet)
    {color, packet} = ItemColor.get_item_color(packet)
    {_color_idx, packet} = get_int(packet)
    {attrs, packet} = get_item_attributes(packet, slot_name)
    attrs = Map.merge(attrs, %{item_id: id, color: color})
    item = Item |> struct(attrs) |> Inventory.load_metadata()
    {item, packet}
  end

  defp get_item_attributes(packet, "HR") do
    {hair, packet} = Item.Hair.get_hair(packet)
    {%{data: hair}, packet}
  end

  defp get_item_attributes(packet, "FD") do
    {data, packet} = get_bytes(packet, 16)
    {%{data: data}, packet}
  end

  defp get_item_attributes(packet, _), do: {%{}, packet}

  defp handle_delete(packet, session) do
    {char_id, _packet} = get_long(packet)
    account = session.account
    character = Enum.find(account.characters, &(&1.id == char_id))

    with %Character{} <- character,
         {:ok, _} <- Characters.delete(character) do
      account = Users.load_characters(account, force: true)

      session
      |> Map.put(:account, account)
      |> push(Packets.CharacterMaxCount.set_max(4, 6))
      |> push(Packets.CharacterList.start_list())
      |> push(Packets.CharacterList.add_entries(account.characters))
      |> push(Packets.CharacterList.end_list())
    else
      _ -> session
    end
  end
end
