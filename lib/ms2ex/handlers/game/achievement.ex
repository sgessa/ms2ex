defmodule Ms2ex.GameHandlers.Achievement do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @claim_reward 0x03
  @toggle_favorite 0x04

  def handle(packet, %{character_id: character_id}) do
    {command, packet} = get_byte(packet)
    {:ok, character} = Managers.Character.lookup(character_id)
    handle_command(command, packet, character)
  end

  defp handle_command(@claim_reward, packet, character) do
    {achievement_id, _packet} = get_int(packet)
    Managers.Achievement.claim_reward(character, achievement_id)
  end

  defp handle_command(@toggle_favorite, packet, character) do
    {achievement_id, packet} = get_int(packet)
    {favorite, _packet} = get_bool(packet)
    Managers.Achievement.toggle_favorite(character, achievement_id, favorite)
  end

  defp handle_command(_command, _packet, _character), do: :ok
end
