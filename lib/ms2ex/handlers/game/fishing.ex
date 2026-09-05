defmodule Ms2ex.GameHandlers.Fishing do
  @moduledoc """
  Fishing requests: casting a rod, dropping the line on a water tile,
  resolving the bite and reeling in.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Ms2ex.Packets.PacketReader

  @prepare 0x0
  @stop 0x1
  @catch_fish 0x8
  @start 0x9
  @fail_minigame 0xA

  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id) do
      case handle_command(command, packet, character) do
        {:error, error} -> push(session, Packets.Fishing.error(error))
        _ -> session
      end
    end

    session
  end

  defp handle_command(@prepare, packet, character) do
    {rod_uid, _packet} = get_long(packet)
    Context.Fishing.prepare(character, rod_uid)
  end

  defp handle_command(@stop, _packet, character), do: Context.Fishing.stop(character)

  defp handle_command(@catch_fish, packet, character) do
    {success?, _packet} = get_bool(packet)
    Context.Fishing.catch_fish(character, success?)
  end

  defp handle_command(@start, packet, character) do
    {position, _packet} = get_sbyte_coord(packet)
    Context.Fishing.start(character, position)
  end

  defp handle_command(@fail_minigame, _packet, character),
    do: Context.Fishing.fail_minigame(character)

  defp handle_command(_command, _packet, _character), do: :ok
end
