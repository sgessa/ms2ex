defmodule Ms2ex.Enums.PartySearchError do
  use Ms2ex.Enum, %{
    none: 0,
    server_db: 2,
    already_registered: 13,
    last_action: 99,
    not_chief: 101,
    invalid_type: 102,
    registering: 103,
    in_party: 104,
    not_find_recruit: 106,
    banword_title: 108,
    blocked: 109,
    max_member: 110,
    party_invited: 111
  }
end
