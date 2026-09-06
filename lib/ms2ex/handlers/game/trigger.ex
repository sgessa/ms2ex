defmodule Ms2ex.GameHandlers.Trigger do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Packets.PacketReader

  @widget_types %{1 => :guide, 5 => :scene_movie, 12 => :round}

  # the client drives scripted sequences from here: widget updates (guide
  # events it fired, scene movies it finished) and cutscene skip requests
  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      0x7 -> skip_cutscene(session)
      0x8 -> update_widget(packet, session)
      _ -> session
    end
  end

  # no payload: the player pressed the cutscene skip button
  defp skip_cutscene(session) do
    with {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.call(character.field_pid, {:skip_cutscene})
    end

    session
  end

  defp update_widget(packet, session) do
    {widget_type, packet} = get_byte(packet)
    {arg, _packet} = get_int(packet)

    with {:ok, widget_key} <- Map.fetch(@widget_types, widget_type),
         {:ok, character} <- Managers.Character.call(session.character_id, :lookup) do
      Context.Field.call(character.field_pid, {:update_widget, widget_key, arg})

      # echoing the movie stop lets the client reset its player state
      if widget_key == :scene_movie, do: push(session, Packets.Trigger.skip_movie(arg))
    end

    session
  end
end
