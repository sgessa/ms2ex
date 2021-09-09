defmodule Ms2ex.GameHandlers.Helper.Session do
  alias Ms2ex.{Character, Field}
  alias Phoenix.PubSub

  def init_character(%Character{} = character) do
    notify_friend_presence(character)
  end

  def cleanup(character) do
    Field.leave(character)
    notify_friend_presence(character)
  end

  defp notify_friend_presence(character) do
    for friend <- character.friends do
      PubSub.subscribe(Ms2ex.PubSub, "friend_presence:#{friend.rcpt_id}")

      data = %{character: character, shared_id: friend.shared_id}
      PubSub.broadcast(Ms2ex.PubSub, "friend_presence:#{character.id}", {:friend_presence, data})
    end
  end
end
