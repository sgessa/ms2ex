defmodule Ms2ex.Managers.Field.Buff do
  alias Ms2ex.Context
  alias Ms2ex.Types
  alias Ms2ex.Managers
  alias Ms2ex.Packets

  def add_buff(skill_cast, skill, character, state) do
    object_id = state.counter + 1
    buff = Types.Buff.new(object_id, skill_cast, skill, character, character)
    Managers.Buff.start(buff)

    Context.Field.broadcast(state.topic, Packets.Buff.send(:add, buff))

    # TODO
    # Process.send_after(self(), {:remove_buff, buff}, buff.duration)

    %{state | counter: object_id}
  end
end
