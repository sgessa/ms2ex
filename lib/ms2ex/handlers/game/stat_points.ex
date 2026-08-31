defmodule Ms2ex.GameHandlers.StatPoints do
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  import Ms2ex.Packets.PacketReader
  import Ms2ex.Net.SenderSession, only: [push: 2]

  # matches C# AttributePointHandler Command enum
  @cmd_increment 2
  @cmd_reset 3

  def handle(packet, %{character_id: character_id} = session) do
    {cmd, packet} = get_byte(packet)
    {:ok, character} = Managers.Character.lookup(character_id)

    case cmd do
      @cmd_increment ->
        {attribute_id, _packet} = get_byte(packet)

        case Managers.Character.allocate_stat_point(character, attribute_id) do
          {:ok, _character} -> :ok
          :error -> :ok
        end

      @cmd_reset ->
        case Managers.Character.reset_stat_points(character) do
          {:ok, _character} ->
            :ok

          :error ->
            push(session, Packets.Notice.message("s_char_info_reset_stat_pointsuccess_msg"))
        end

      _ ->
        :ok
    end

    session
  end
end
