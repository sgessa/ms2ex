defmodule Ms2ex.LoginHandlers.Ugc do
  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  @profile_picture 0x0B

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    handle_command(command, packet, session)
  end

  defp handle_command(
         @profile_picture,
         packet,
         %{account: account, character_id: character_id} = session
       )
       when not is_nil(account) and not is_nil(character_id) do
    {url, _packet} = get_ustring(packet)

    with %Schema.Character{} = character <- Context.Characters.get(account, character_id),
         {:ok, character} <- Context.Characters.update(character, %{profile_url: url}) do
      push(session, Packets.Ugc.profile_picture(character))
    else
      _ ->
        Logger.warning("Cannot set profile picture for character #{character_id}")
        session
    end
  end

  defp handle_command(_command, _packet, session), do: session
end
