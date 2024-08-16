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

  def update(character, %{activated: false} = buff, tick) do
    cancel_meta = buff.skill_cast[:meta][:update][:cancel]

    if buff.skill_id in cancel_meta[:ids] &&
         (!cancel_meta[:check_same_caster] || buff.owner.object_id == buff.caster.object_id) do
      remove_buff(character, buff.object_id)
    else
      buff = Map.put(buff, :activated, true)
      update(character, buff, tick)
    end
  end

  def update(
        character,
        %{can_expire: true, can_proc: false, end_tick: end_tick} = buff,
        tick_count
      )
      when tick_count > end_tick do
    remove_buff(character, buff.object_id)
  end

  def update(character, _buff, _tick), do: character

  def remove_buff(character, object_id) do
    pop_in(character, [:buffs, object_id])
  end
end
