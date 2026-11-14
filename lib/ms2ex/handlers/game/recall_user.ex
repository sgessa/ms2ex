defmodule Ms2ex.GameHandlers.RecallUser do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartyServer

  import Ms2ex.Packets.PacketReader

  # A member answering a summon prompt: mode 4 carries their accept/decline
  # for a request id; mode 7 is the automatic reply for a prompt that
  # arrived while another one was still open.
  @impl true
  def commands, do: %{reply: 0x4, busy: 0x7}

  @impl true
  def spec(0x4) do
    [request_id: :int, accepted: {:byte, &(&1 == 1)}]
  end

  def spec(0x7) do
    [caster_name: :ustring, _flag: :byte]
  end

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(0x4, packet, session) do
    {request_id, packet} = get_int(packet)
    {accepted?, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, caster_id} <-
           PartyServer.call(
             character.party_id,
             {:recall_reply, character.id, request_id, accepted?}
           ),
         true <- accepted?,
         {:ok, caster} <- Managers.Character.call(caster_id, :lookup) do
      Managers.Field.summon_to_field(caster, character)
    else
      _ -> :ok
    end

    session
  end

  defp handle_mode(0x7, packet, session) do
    {caster_name, _packet} = get_ustring(packet)

    case Managers.Character.call(session.character_id, :lookup) do
      {:ok, character} ->
        PartyServer.cast(character.party_id, {:recall_busy, character.id, caster_name})

      _ ->
        :ok
    end

    session
  end

  defp handle_mode(_mode, _packet, session), do: session
end
