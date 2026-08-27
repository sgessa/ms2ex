defmodule Ms2ex.Managers.Field.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets

  def add_buff(skill_cast, skill, character, state) do
    {object_id, state} = Managers.Field.next_local_id(state)
    buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    reset_skill_cooldowns(buff, character)

    # TODO
    # Process.send_after(self(), {:remove_buff, buff}, buff.duration)

    state
  end

  defp reset_skill_cooldowns(buff, character) do
    case get_in(buff.effect, [:update, :reset_cooldown]) do
      skill_ids when is_list(skill_ids) and skill_ids != [] ->
        Enum.each(skill_ids, fn skill_id ->
          {:ok, cooldown} = Managers.Character.set_skill_cooldown(character, skill_id, 1, 0)
          Net.SenderSession.push(character, Packets.SkillCooldown.bytes([cooldown]))
        end)

      _ ->
        :ok
    end
  end
end
