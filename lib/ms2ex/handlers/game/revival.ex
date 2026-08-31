defmodule Ms2ex.GameHandlers.Revival do
  alias Ms2ex.Managers

  import Ms2ex.Packets.PacketReader

  @safe_revive 0x0
  @instant_revive 0x2

  # client picks a revive option after death: safe revive (respawn at spawn
  # point) or instant revive (stay in place, costing mesos / a coupon)
  def handle(packet, session) do
    {command, packet} = get_byte(packet)

    case command do
      @safe_revive ->
        Managers.Character.cast(session.character_id, {:revive, :safe})

      @instant_revive ->
        {use_voucher, _packet} = get_bool(packet)
        Managers.Character.cast(session.character_id, {:revive, :instant, use_voucher})

      _ ->
        :ok
    end
  end
end
