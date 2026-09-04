defmodule Ms2ex.GameHandlers.ItemLock do
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  # Reset
  defp handle_mode(0x00, _packet, session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Managers.Inventory.call(character.id, :lock_reset)
    end

    session
  end

  # Stage: stage an item for locking (unlock = false) or unlocking
  defp handle_mode(0x01, packet, session) do
    {_unlock, packet} = get_bool(packet)
    {uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, index} <- Managers.Inventory.call(character.id, {:lock_stage, uid}) do
      push(session, Packets.ItemLock.stage(uid, index))
    end

    session
  end

  # Unstage
  defp handle_mode(0x02, packet, session) do
    {uid, _packet} = get_long(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         :ok <- Managers.Inventory.call(character.id, {:lock_unstage, uid}) do
      push(session, Packets.ItemLock.unstage(uid))
    end

    session
  end

  # Commit: applies the staged locks/unlocks and replies with the updated items
  defp handle_mode(0x03, packet, session) do
    {unlock, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, items} <- Managers.Inventory.call(character.id, {:lock_commit, unlock}) do
      push(session, Packets.ItemLock.commit(items, character))
    end

    session
  end

  defp handle_mode(_mode, _packet, session), do: session
end
