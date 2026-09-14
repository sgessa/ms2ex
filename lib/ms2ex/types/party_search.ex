defmodule Ms2ex.Types.PartySearch do
  defstruct [
    :id,
    :party_id,
    :name,
    :no_approval,
    :size,
    :member_count,
    :leader_account_id,
    :leader_character_id,
    :leader_name,
    :created_at,
    members: []
  ]

  def new(id, party, name, no_approval, size) do
    leader = Ms2ex.Types.Party.get_leader(party)

    %__MODULE__{
      id: id,
      party_id: party.id,
      name: name,
      no_approval: no_approval,
      size: size,
      member_count: Enum.count(party.members),
      leader_account_id: leader.account_id,
      leader_character_id: leader.id,
      leader_name: leader.name,
      created_at: DateTime.to_unix(DateTime.utc_now()),
      members: party.members
    }
  end
end
