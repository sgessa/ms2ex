defmodule Ms2ex.Managers.Character.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Packets

  def add_buff(character, object_id, skill_cast, skill) do
    buff = Types.Buff.build(object_id, skill_cast, skill, character, character)

    Context.Field.broadcast(character, Packets.Buff.send(:add, buff))

    add(character, buff)
  end

  def add(character, buff) do
    buffs = Map.put(character.buffs, buff.object_id, buff)
    %{character | buffs: buffs}
  end
end
