defmodule Ms2ex.GameHandlers.Helper.Friend do
  alias Ms2ex.{Managers, Context, Packets}

  @friend_list_max_size 100

  def find_rcpt(rcpt_name) do
    rcpt = find_from_world(rcpt_name) || find_from_db(rcpt_name)

    if rcpt do
      {:ok, rcpt}
    else
      {:error, Packets.Friend.notice(:char_not_found, rcpt_name)}
    end
  end

  defp find_from_db(char_name) do
    Context.Characters.get_by(name: char_name)
    |> Context.Characters.preload(:friends)
  end

  defp find_from_world(char_name) do
    case Managers.Character.lookup_by_name(char_name) do
      {:ok, char} -> char
      _ -> nil
    end
  end

  def validate_rcpt(character, rcpt) do
    if character.id != rcpt.id do
      :ok
    else
      {:error, Packets.Friend.notice(:cannot_add_self, rcpt.name)}
    end
  end

  def check_block_list_size(character, rcpt, error_notice) do
    size = character.friends |> Enum.count(&(&1.status == :blocked))

    if size < @friend_list_max_size do
      :ok
    else
      {:error, Packets.Friend.notice(error_notice, rcpt.name)}
    end
  end

  def check_friend_list_size(character, rcpt, error_notice) do
    size = character.friends |> Enum.count(&(&1.status != :blocked))

    if size < @friend_list_max_size do
      :ok
    else
      {:error, Packets.Friend.notice(error_notice, rcpt.name)}
    end
  end

  # check if rcpt blocked character
  def check_block_list(character, rcpt) do
    if Enum.find(rcpt.friends, &(&1.rcpt_id == character.id and &1.status == :blocked)) do
      {:error, Packets.Friend.notice(:declined_request, rcpt.name)}
    else
      :ok
    end
  end

  def check_is_already_friend(character, rcpt) do
    if Enum.find(character.friends, &(&1.rcpt_id == rcpt.id and &1.status != :blocked)) do
      {:error, Packets.Friend.notice(:already_friends, rcpt.name)}
    else
      :ok
    end
  end

  def remove_friend_from_session(character, shared_id) do
    new_friends = Enum.reject(character.friends, &(&1.shared_id == shared_id))
    character = Map.put(character, :friends, new_friends)
    Managers.Character.update(character)
  end
end
