defmodule Ms2ex.Managers.Field.Skill do
  alias Ms2ex.Types
  alias Ms2ex.Context
  alias Ms2ex.Packets

  # -------------------------------
  # Skills
  # -------------------------------

  def add_field_skill(state, attrs) do
    counter = state.counter

    {counter, skills} =
      Types.FieldSkill.build(state.topic, attrs)
      |> Enum.reduce({counter, state.skills}, fn field_skill, {counter, skills} ->
        object_id = counter + 1
        field_skill = Map.put(field_skill, :object_id, object_id)
        Context.Field.broadcast(state.topic, Packets.RegionSkill.add(field_skill))

        skills = Map.put(skills, object_id, field_skill)

        {object_id, skills}
      end)

    %{state | counter: counter, skills: skills}
  end

  def remove_field_skill(state, object_id) do
    Context.Field.broadcast(state.topic, Packets.RegionSkill.remove(object_id))
    pop_in(state, [:skills, object_id])
  end

  def update(state, %{enabled: false} = field_skill, _tick_count) do
    remove_field_skill(state, field_skill.object_id)
  end

  def update(state, field_skill, tick_count) do
    if tick_count < field_skill.next_tick do
      state
    else
      field_skill = update_motions(field_skill)
      update_in(state, [:skills, field_skill.object_id], fn _ -> field_skill end)
    end
  end

  defp update_motions(%{active: false} = field_skill) do
    field_skill[:meta][:motions]
    |> Enum.flat_map(fn motion ->
      Enum.map(motion[:attacks], fn _attack ->
        false
        # rotation = if field_skill.use_direction, do: field_skill.rotation.z, else: 0
        # TODO: prisms = Enum.map(field_skill.points, &get_prism(&1, rotation))
        # TODO: Enum.any?(get_targets(prisms, attack[:range][:apply_target], attack[:target_count]))
      end)
    end)
    |> Enum.uniq()
    |> Enum.any?(fn f -> f == true end)
    |> case do
      true -> %{field_skill | active: true}
      false -> %{field_skill | next_tick: Ms2ex.sync_ticks() + field_skill.interval}
    end
  end

  defp update_motions(field_skill), do: field_skill
end
