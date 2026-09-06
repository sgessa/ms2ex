defmodule Ms2ex.GameHandlers.GuideObjectSync do
  @moduledoc """
  Movement of a guide object (the fishing bobber). Only its owner controls it,
  so the server relays the states to the rest of the field and follows along
  with the last one.
  """

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Managers.Character.Fishing
  alias Ms2ex.Packets
  alias Ms2ex.Types

  import Ms2ex.Packets.PacketReader

  def handle(packet, session) do
    {type, packet} = get_short(packet)
    {segments, packet} = get_byte(packet)

    with true <- segments > 0,
         {:ok, character} <- Managers.Character.lookup(session.character_id),
         %{guide: guide} <- Fishing.session(character),
         ^type <- Enums.GuideObjectType.get_value(guide.type) do
      {sync_states, _packet} = read_states(segments, packet)

      Context.Field.broadcast_from(
        character,
        Packets.GuideObject.sync(guide.object_id, sync_states),
        session.sender_pid
      )

      follow(character, List.last(sync_states))
    end

    session
  end

  defp read_states(count, packet) do
    Enum.reduce(1..count, {[], packet}, fn _segment, {states, packet} ->
      {state, packet} = Types.SyncState.from_packet(packet)
      {_client_tick, packet} = get_int(packet)
      {_server_tick, packet} = get_int(packet)

      {states ++ [state], packet}
    end)
  end

  # the bobber only ever rotates around Z
  defp follow(character, %{position: position, rotation: rotation}) do
    Managers.Character.cast(
      character,
      {:fishing_guide_moved, position, %Types.Coord{x: 0, y: 0, z: rotation}}
    )
  end

  defp follow(_character, _state), do: :ok
end
