defmodule Ms2ex.GameHandlers.InteractObject do
  @moduledoc """
  Player interactions with field objects (weeds, telescopes, gathering
  nodes, ...). The client opens the interaction with Start and completes it
  with End; End is what counts towards interact-object quest conditions.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @start 0x0B
  @end_command 0x0C

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    {uuid, _packet} = get_string(packet)

    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      case command do
        @start -> :ok
        @end_command -> complete_interaction(character, uuid)
        _ -> :ok
      end
    end

    :ok
  end

  defp complete_interaction(character, uuid) do
    case Context.Field.interact_object(character, uuid) do
      {:ok, object_id} ->
        Managers.Quest.update_conditions(character.id, :interact_object, 1, "", 0, "", object_id)

        Managers.Quest.update_conditions(
          character.id,
          :interact_object_rep,
          1,
          "",
          0,
          "",
          object_id
        )

      :error ->
        :ok
    end
  end
end
