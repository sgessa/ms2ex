defmodule Ms2ex.Party do
  @max_members 10

  defstruct [
    :id,
    :leader_id,
    :formed_at,
    :pid,
    members: [],
    ready_check: [],
    vote_kick: []
  ]

  def create(leader) do
    %__MODULE__{
      id: Ms2ex.generate_id(),
      formed_at: DateTime.utc_now(),
      leader_id: leader.id,
      members: [leader],
      pid: self()
    }
  end

  def get_leader(%__MODULE__{leader_id: leader_id, members: members}) do
    Enum.find(members, &(&1.id == leader_id))
  end

  def get_member(%__MODULE__{members: members}, member_id) do
    Enum.find(members, &(&1.id == member_id))
  end

  def add_member(party, character) do
    members = [character | party.members]
    %{party | members: members}
  end

  def update_member(party, character) do
    case Enum.find_index(party.members, &(&1.id == character.id)) do
      nil ->
        party

      index ->
        members = List.update_at(party.members, index, fn _ -> character end)
        %{party | members: members}
    end
  end

  def remove_member(party, character) do
    case Enum.find_index(party.members, &(&1.id == character.id)) do
      nil ->
        party

      index ->
        %{party | members: List.delete_at(party.members, index)}
    end
  end

  def in_party?(party, character) do
    !!Enum.find(party.members, &(&1.id == character.id))
  end

  def is_leader?(party, character) do
    party.leader_id == character.id
  end

  def full?(party), do: Enum.count(party.members) >= @max_members
  def new?(party), do: Enum.count(party.members) == 1

  def ready_check_in_progress?(%__MODULE__{ready_check: r}) do
    Enum.count(r) > 0
  end
end
