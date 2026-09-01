defmodule Ms2ex.GameHandlers.UserEnv do
  alias Ms2ex.Managers
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Packets.PacketReader

  def handle(packet, session) do
    {mode, packet} = get_byte(packet)
    handle_mode(mode, packet, session)
  end

  defp handle_mode(0x1, packet, session) do
    {title_id, _packet} = get_int(packet)

    if title_id >= 0 do
      {:ok, character} = Managers.Character.call(session.character_id, :lookup)
      {:ok, character} = Context.Characters.update(character, %{title_id: title_id})
      Managers.Character.call(character, {:update, character})

      Context.Field.broadcast(character, Packets.UserEnv.update_title(character))
    end
  end

  defp handle_mode(_mode, _packet, session), do: session
end
