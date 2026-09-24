defmodule Ms2ex.GameHandlers.KeyTable do
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Set Game Key Binds / Set Key Binds: upsert each binding by key code
  defp handle_mode(mode, packet, session) when mode in [0x1, 0x2] do
    {count, packet} = get_int(packet)
    {binds, _packet} = read_key_binds(count, packet, %{})

    if binds != %{} do
      :ok = Managers.CharacterConfig.merge_key_binds(session.character_id, binds)
    end
  end

  # Move / Add Quick Slot
  defp handle_mode(mode, packet, session) when mode in [0x3, 0x4] do
    {bar_index, packet} = get_short(packet)
    {quick_slot, packet} = Types.QuickSlot.get_quick_slot(packet)
    {target_slot, _packet} = get_int(packet)
    character_id = session.character_id

    result = Managers.CharacterConfig.move_quick_slot(character_id, bar_index, quick_slot, target_slot)

    with :ok <- result do
      push(session, Packets.KeyTable.send_hot_bars(Managers.CharacterConfig.list(character_id)))
    end
  end

  # Remove Quick Slot
  defp handle_mode(0x5, packet, session) do
    {bar_index, packet} = get_short(packet)
    {skill_id, packet} = get_int(packet)
    {item_uid, _packet} = get_long(packet)
    character_id = session.character_id

    result = Managers.CharacterConfig.remove_quick_slot(character_id, bar_index, skill_id, item_uid)

    with :ok <- result do
      push(session, Packets.KeyTable.send_hot_bars(Managers.CharacterConfig.list(character_id)))
    end
  end

  # Key-table re-sync request: a skill-set buff (e.g. the tutorial's training
  # swap) changing or reverting makes the client drop the swapped bar entries
  # and ask for the authoritative layout back
  defp handle_mode(0x7, _packet, session) do
    bars = Managers.CharacterConfig.list(session.character_id)
    push(session, Packets.KeyTable.send_hot_bars(bars))
  end

  # Set Active Hot Bar
  defp handle_mode(0x8, packet, session) do
    {bar_index, _packet} = get_short(packet)
    :ok = Managers.CharacterConfig.set_active_bar(session.character_id, bar_index)
  end

  defp handle_mode(_mode, _packet, _session), do: :ok

  defp read_key_binds(0, packet, acc), do: {acc, packet}

  defp read_key_binds(count, packet, acc) do
    {bind, packet} = Types.KeyBind.get_key_bind(packet)
    read_key_binds(count - 1, packet, Map.put(acc, bind.key_code, bind))
  end
end
