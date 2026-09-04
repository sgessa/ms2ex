defmodule Ms2ex.GameHandlers.Insignia do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Storage
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {insignia_id, _packet} = get_short(packet)
    {:ok, character} = Managers.Character.call(session.character_id, :lookup)

    # an id absent from the table is ignored; otherwise the insignia is
    # applied and the display flag broadcast
    case Storage.Tables.Insignias.get(insignia_id) do
      {:ok, metadata} ->
        worn = character.insignia_id
        display = Context.Insignias.display?(character, metadata)

        {:ok, character} = Context.Characters.update(character, %{insignia_id: insignia_id})
        Managers.Character.call(character, {:update, character})

        # the buff swap has to follow the character write: {:update, ...}
        # replaces the manager's state wholesale and would discard the stat
        # change the removal makes
        remove_insignia_buff(character, worn)
        if display, do: apply_insignia_buff(character, metadata)

        Context.Field.broadcast(
          character,
          Packets.Insignia.update(character, insignia_id, display)
        )

      :error ->
        :ok
    end
  end

  # the insignia the player was wearing keeps its buff until it is swapped out
  defp remove_insignia_buff(character, worn) do
    with {:ok, %{buff_id: buff_id}} <- Storage.Tables.Insignias.get(worn),
         true <- buff_id > 0 do
      Context.Field.remove_effect_buff(character, buff_id)
    else
      _ -> :ok
    end
  end

  defp apply_insignia_buff(character, %{buff_id: buff_id, buff_level: buff_level})
       when buff_id > 0 do
    Context.Field.call(character, {:add_effect_buff, buff_id, buff_level, character})
  end

  defp apply_insignia_buff(_character, _metadata), do: :ok
end
