defmodule Ms2ex.Managers.Character.FallDamage do
  alias Ms2ex.Managers.Character
  alias Ms2ex.Context
  alias Ms2ex.Packets

  import Ms2ex.Net.SenderSession, only: [push: 2]

  def receive_fall_damage(character, distance) do
    hp = Map.get(character.stats, :health_cur)
    dmg = Context.Damage.calculate_fall_dmg(character, distance)
    character = Character.Stats.set(character, :health, hp - dmg)

    push(character, Packets.FallDamage.bytes(character, dmg))

    character
  end
end
