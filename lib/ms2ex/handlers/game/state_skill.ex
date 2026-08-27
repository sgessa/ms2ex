defmodule Ms2ex.GameHandlers.StateSkill do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Packets.PacketReader

  def handle(packet, session) do
    {function, packet} = get_byte(packet)

    if function != 0x0 do
      :ok
    else
      {cast_uid, packet} = get_long(packet)
      {server_tick, packet} = get_int(packet)
      {skill_id, packet} = get_int(packet)
      {skill_level, packet} = get_short(packet)
      {state, packet} = get_int(packet)
      {client_tick, packet} = get_int(packet)
      {item_uid, _packet} = get_long(packet)

      {:ok, character} = Managers.Character.lookup(session.character_id)

      with true <- Storage.Skills.get_meta(skill_id) != nil,
           true <- owned_item?(character, item_uid) do
        skill_cast =
          Types.SkillCast.build(character, %{
            id: cast_uid,
            skill_id: skill_id,
            skill_level: skill_level,
            server_tick: server_tick,
            client_tick: client_tick
          })

        Managers.SkillCast.start_link(skill_cast)

        Context.Field.broadcast(
          character,
          Packets.StateSkill.bytes(character, skill_id, cast_uid, state)
        )
      end
    end
  end

  defp owned_item?(_character, 0), do: true
  defp owned_item?(character, item_uid), do: Context.Inventory.get(character, item_uid) != nil
end
