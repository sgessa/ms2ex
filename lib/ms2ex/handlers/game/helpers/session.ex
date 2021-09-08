defmodule Ms2ex.GameHandlers.Helper.Session do
  alias Ms2ex.{Character, Field, Friends, World}

  def init_character(%Character{} = character) do
    notify_friend_presence(character)
  end

  def cleanup(character) do
    Field.leave(character)
    notify_friend_presence(character)
  end

  defp notify_friend_presence(character) do
    reverse_friends = Friends.get_reverse_friends(character)
    Enum.each(reverse_friends, &World.send_presence_notification(&1))
  end
end
