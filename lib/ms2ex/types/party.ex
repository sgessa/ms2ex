defmodule Ms2ex.Party do
  defstruct [
    :id,
    :leader_id,
    :formed_at,
    :pid,
    members: []
  ]

  def create(leader) do
    struct(__MODULE__, %{
      id: Ms2ex.generate_id(),
      formed_at: DateTime.utc_now(),
      leader_id: leader.id,
      members: [leader],
      pid: self()
    })
  end

  def get_leader(%__MODULE__{leader_id: leader_id, members: members}) do
    Enum.find(members, &(&1.id == leader_id))
  end
end
