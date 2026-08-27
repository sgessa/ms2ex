defmodule Ms2ex.Packets.SkillCooldown do
  import Ms2ex.Packets.PacketWriter

  def bytes(cooldowns) do
    __MODULE__
    |> build()
    |> put_byte(length(cooldowns))
    |> reduce(cooldowns, fn cooldown, packet ->
      packet
      |> put_int(cooldown.skill_id)
      |> put_int(cooldown.group_id)
      |> put_int(cooldown.end_tick)
      |> put_int(cooldown.charges)
    end)
  end
end
