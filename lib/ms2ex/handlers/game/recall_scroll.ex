defmodule Ms2ex.GameHandlers.RecallScroll do
  @behaviour Ms2ex.Packets.Spec

  alias Ms2ex.Managers
  alias Ms2ex.Managers.PartyServer
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # A member accepting a follow prompt: identifies the prompt's caster by
  # name; the slot byte repeats the prompt type the client was shown.
  @impl true
  def spec(_command) do
    [
      slot: :byte,
      caster_name: :ustring,
      _map_id: :int
    ]
  end

  def handle(packet, session) do
    {slot, packet} = get_byte(packet)
    {caster_name, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup),
         {:ok, caster} <-
           PartyServer.call(character.party_id, {:accept_recall, character, slot, caster_name}) do
      Managers.Field.summon_to_field(caster, character)
      push(session, Packets.RecallScroll.close(slot))
    else
      _ -> :ok
    end

    session
  end
end
