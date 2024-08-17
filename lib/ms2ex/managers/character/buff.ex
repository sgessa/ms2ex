defmodule Ms2ex.Managers.Character.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Packets
  alias Ms2ex.Enums

  def add_buff(character, object_id, skill_cast, skill) do
    buff = Types.Buff.build(object_id, skill_cast, skill, character, character)

    Context.Field.broadcast(character, Packets.Buff.send(:add, buff))

    add(character, buff)
  end

  def add(character, buff) do
    buffs = Map.put(character.buffs, buff.object_id, buff)
    %{character | buffs: buffs}
  end

  # Remove or activate buff
  def update(character, %{activated: false} = buff, tick) do
    cancel_meta = buff.skill_cast.meta[:update][:cancel]
    cancel_ids = cancel_meta[:ids] || []

    if buff.skill[:id] in cancel_ids &&
         (!cancel_meta[:check_same_caster] || buff.owner.object_id == buff.caster.object_id) do
      remove_buff(character, buff.object_id)
    else
      buff = Map.put(buff, :activated, true)
      update(character, buff, tick)
    end
  end

  # Remove buff if current tick is higher than end tick
  def update(
        character,
        %{can_expire: true, can_proc: false, end_tick: end_tick} = buff,
        tick_count
      )
      when tick_count > end_tick,
      do: remove_buff(character, buff.object_id)

  # Skip update if current tick is less than next_proc_tick or not can_proc
  def update(character, %{can_proc: can_proc, next_proc_tick: next_proc_tick}, tick)
      when not can_proc or tick < next_proc_tick,
      do: character

  def update(character, buff, _tick) do
    buff = Map.put(buff, :proc_count, buff.proc_count + 1)

    # TODO properties
    # ApplyRecovery();
    # ApplyDotDamage();
    # ApplyDotBuff();
    # ApplyCancel();
    # ModifyDuration();

    for effect <- buff.effect[:skills] do
      apply_effect(character, buff, effect)
    end

    buff = Map.put(buff, :next_proc_tick, buff.next_proc_tick + buff.interval_tick)
    buff = if buff.next_proc_tick > buff.end_tick, do: Map.put(buff, :can_proc, false), else: buff

    buffs = Map.put(character.buffs, buff.object_id, buff)
    Map.put(character, :buffs, buffs)
  end

  def remove_buff(character, object_id) do
    if buff = character.buffs[object_id] do
      Context.Field.broadcast(character, Packets.Buff.send(:remove, buff))

      buffs = Map.delete(character.buffs, object_id)
      Map.put(character, :buffs, buffs)
    else
      character
    end
  end

  # Send/update buff to target
  defp apply_effect(character, buff, %{condition: %{target: target_type}} = effect) do
    target =
      case Enums.SkillEntity.get_key(target_type) do
        :target ->
          buff.owner

        :caster ->
          buff.caster
      end

    Context.Field.call(character, {:add_buff, buff.skill_cast, effect, target})
  end

  # Send/update effect if any
  defp apply_effect(character, buff, %{splash: _splash} = effect) do
    field_skill = %{
      meta: effect,
      caster: buff.caster,
      points: [buff.owner.position],
      rotation: buff.owner.rotation,
      skill_id: buff.skill[:id],
      skill_level: buff.skill[:level]
    }

    Context.Field.call(character, {:add_field_skill, field_skill})
  end

  defp apply_effect(_character, _buff, _effect), do: :no_effect
end
