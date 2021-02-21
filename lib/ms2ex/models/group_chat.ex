defmodule Ms2ex.GroupChat do
  defstruct [:id, members: []]

  @max_members 20
  def max_members(), do: @max_members

  @max_chats_per_user 3
  def max_chats_per_user(), do: @max_chats_per_user

  def add_member(%__MODULE__{members: members} = chat, new_member) do
    members = [new_member | members]
    %{chat | members: members}
  end

  def remove_member(%__MODULE__{members: members} = chat, member) do
    members = Enum.filter(members, &(&1.id == member.id))
    %{chat | members: members}
  end
end
