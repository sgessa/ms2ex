defmodule Ms2ex.Types.GuildRank do
  import Bitwise

  defstruct [:id, :name, permission: 1]

  @permissions %{
    default: 1,
    invite_members: 2,
    expel_members: 4,
    edit_notice: 8,
    unknown: 16,
    edit_rank: 32,
    edit_emblem: 64,
    send_mail: 128,
    start_pvp: 256,
    use_buff: 512,
    start_mini_game: 1024,
    send_alert: 2048
  }

  def permissions, do: @permissions

  def permission_value(name) when is_atom(name), do: Map.get(@permissions, name, 0)
  def permission_value(val) when is_integer(val), do: val

  def has_permission?(%__MODULE__{permission: perm}, flag) when is_atom(flag) do
    val = Map.get(@permissions, flag, 0)
    (perm &&& val) != 0
  end

  def has_permission?(%__MODULE__{permission: perm}, flag) when is_integer(flag) do
    (perm &&& flag) != 0
  end

  def has_permission?(_rank, _flag), do: false

  def default_ranks do
    [
      %__MODULE__{id: 0, name: "Master", permission: 4095},
      %__MODULE__{
        id: 1,
        name: "Jr. Master",
        permission: 1 + 2 + 4 + 8 + 16 + 32 + 64 + 128 + 256 + 512 + 1024 + 2048
      },
      %__MODULE__{id: 2, name: "Veteran", permission: 1},
      %__MODULE__{id: 3, name: "Member", permission: 1},
      %__MODULE__{id: 4, name: "Recruit", permission: 1}
    ]
  end
end
