defmodule Ms2ex.LoginHandlers.CharacterManagement do
  alias Ms2ex.Context
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Repo
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Managers.Session
  alias Ms2ex.Types
  alias Ms2ex.Enums

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

  # Cancel Delete Character
  def handle(<<0x3, packet::bytes>>, session) do
    handle_cancel_delete(packet, session)
  end

  # Confirm Delete Character
  def handle(<<0x4, packet::bytes>>, session) do
    handle_delete(packet, session)
  end

  defp handle_login(packet, %{account: account} = session) do
    {char_id, _packet} = get_long(packet)

    case Context.Characters.get(account, char_id) do
      %Schema.Character{} ->
        auth_data = %{token_a: Ms2ex.generate_int(), token_b: Ms2ex.generate_int()}
        register_session(account.id, char_id, auth_data)
        send(self(), {:update, %{character_id: char_id}})
        push(session, Packets.LoginToGame.login(auth_data))

      _ ->
        session
    end
  end

  defp register_session(account_id, character_id, auth_data) do
    :ok =
      Session.register(
        account_id,
        Map.merge(auth_data, %{account_id: account_id, character_id: character_id})
      )
  end

  defp handle_create(packet, session) do
    {gender, packet} = get_byte(packet)
    {job_code, packet} = get_short(packet)
    {name, packet} = get_ustring(packet)
    {skin_color, packet} = Types.SkinColor.get_skin_color(packet)
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
      job: Enums.Job.get_key(job_code),
      map_id: start_field(job_code),
      name: name,
      skin_color: skin_color
    }

    result =
      Repo.transaction(fn ->
        case Context.Characters.create(session.account, attrs) do
          {:ok, character} ->
            add_equips(character, equips)
            %{character | equips: Context.Inventory.list_equipped(character.id)}

          error ->
            Repo.rollback(error)
        end
      end)

    case result do
      {:ok, character} ->
        # the client uploads the avatar right after creation, against this character
        send(self(), {:update, %{character_id: character.id}})

        session
        |> push(Packets.CharacterMaxCount.set_max(session.account.max_characters, 8))
        |> push(Packets.CharacterList.append(character))

      _error ->
        push(session, Packets.CharacterCreate.name_taken())
    end
  end

  # new characters begin on their job's tutorial start field; the fallback
  # covers projections without the tutorial block
  defp start_field(job_code) do
    job_code
    |> Storage.Tables.Jobs.tutorial()
    |> case do
      %{start_field: field} when is_integer(field) and field > 0 -> field
      _ -> 2_000_023
    end
  end

  # character creation runs before any game session, so the starting outfit
  # is inserted directly: one row per equipped item, already in place
  defp add_equips(character, equips) do
    Enum.each(equips, fn {equip_slot, item} ->
      {:ok, item} = Context.Inventory.insert_item(character.id, item)

      Schema.Item.bind_if_needed(item, :equip)
      |> Context.Inventory.update_item(%{
        equip_slot: equip_slot,
        inventory_slot: nil,
        location: :equipment
      })
    end)
  end

  defp get_equip(packet) do
    {id, packet} = get_int(packet)
    {slot_name, packet} = get_ustring(packet)
    {color, packet} = Types.ItemColor.get_item_color(packet)
    {_color_idx, packet} = get_int(packet)
    {attrs, packet} = get_item_attributes(packet, slot_name)

    attrs = Map.put(attrs, :color, color)
    item = Context.Items.init(id, attrs)

    {{String.to_existing_atom(slot_name), item}, packet}
  end

  defp get_item_attributes(packet, "HR") do
    {hair, packet} = Types.Hair.get_hair(packet)
    {%{data: hair}, packet}
  end

  defp get_item_attributes(packet, "FD") do
    {data, packet} = get_bytes(packet, 16)
    {%{data: data}, packet}
  end

  defp get_item_attributes(packet, _), do: {%{}, packet}

  defp handle_delete(packet, session) do
    {char_id, _packet} = get_long(packet)

    case Context.Characters.get(session.account, char_id) do
      %Schema.Character{} = character ->
        case validate_delete(character) do
          :ok -> delete_character(character, session)
          {:error, reason} -> push(session, Packets.CharacterList.delete_entry(char_id, reason))
        end

      nil ->
        push(session, Packets.CharacterList.delete_entry(char_id, :s_char_err_already_destroy))
    end
  end

  # a pending deletion past its wait time is finalized; re-requesting an
  # ongoing deletion only re-acks the scheduled time so the client keeps its
  # countdown
  defp delete_character(%Schema.Character{delete_time: delete_time} = character, session)
       when delete_time != 0 do
    if delete_time <= System.system_time(:second) do
      finish_delete(character, session)
    else
      push(
        session,
        Packets.CharacterList.begin_delete(
          character.id,
          delete_time,
          :s_char_err_next_delete_char_date
        )
      )
    end
  end

  # characters below the destroy-division level are removed immediately;
  # higher levels start the deletion wait so the deletion can be cancelled
  defp delete_character(%Schema.Character{} = character, session) do
    division_level = Storage.Tables.Constants.get(:character_destroy_division_level)
    wait_seconds = Storage.Tables.Constants.get(:character_destroy_wait_second)

    if character.level >= division_level do
      delete_time = System.system_time(:second) + wait_seconds

      case Context.Characters.update(character, %{delete_time: delete_time}) do
        {:ok, _} ->
          push(session, Packets.CharacterList.begin_delete(character.id, delete_time))

        _error ->
          push(
            session,
            Packets.CharacterList.begin_delete(character.id, delete_time, :s_char_err_destroy)
          )
      end
    else
      finish_delete(character, session)
    end
  end

  defp finish_delete(character, session) do
    case Context.Characters.delete(character) do
      {:ok, _} ->
        push(session, Packets.CharacterList.delete_entry(character.id))

      _error ->
        push(session, Packets.CharacterList.delete_entry(character.id, :s_char_err_destroy))
    end
  end

  defp handle_cancel_delete(packet, session) do
    {char_id, _packet} = get_long(packet)

    case Context.Characters.get(session.account, char_id) do
      %Schema.Character{delete_time: delete_time} = character when delete_time != 0 ->
        case Context.Characters.update(character, %{delete_time: 0}) do
          {:ok, _} ->
            push(session, Packets.CharacterList.cancel_delete(char_id))

          _error ->
            push(session, Packets.CharacterList.cancel_delete(char_id, :s_char_err_destroy))
        end

      %Schema.Character{} ->
        push(session, Packets.CharacterList.cancel_delete(char_id, :s_char_err_no_destroy_wait))

      nil ->
        push(session, Packets.CharacterList.delete_entry(char_id, :s_char_err_already_destroy))
    end
  end

  defp validate_delete(%Schema.Character{} = character) do
    if Context.Mails.count_unread(character.id) > 0 do
      {:error, :s_char_err_unread_mail}
    else
      validate_guild_membership(character)
    end
  end

  defp validate_guild_membership(character) do
    case Context.Guilds.get_by_character_id(character.id) do
      %{leader_id: leader_id} when leader_id == character.id ->
        {:error, :s_char_err_guild_master}

      %Schema.Guild{} ->
        {:error, :s_char_err_guild}

      nil ->
        :ok
    end
  end
end
