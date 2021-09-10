defmodule Ms2ex.GameHandlers.Helper.Session do
  alias Ms2ex.{Character, Field}
  alias Phoenix.PubSub

  def init_character(%Character{} = character) do
    for %{status: :accepted, is_request: false, rcpt_id: rcpt_id} <- character.friends do
      PubSub.subscribe(Ms2ex.PubSub, "friend_presence:#{rcpt_id}")
    end

    notify_friend_presence(character)

    if character.party_id do
      notify_party_presence(character)
      PubSub.subscribe(Ms2ex.PubSub, "party:#{character.party_id}")
    end
  end

  def cleanup(character) do
    Field.leave(character)
    notify_friend_presence(character)
  end

  defp notify_friend_presence(character) do
    for friend <- character.friends do
      data = %{character: character, shared_id: friend.shared_id}
      PubSub.broadcast(Ms2ex.PubSub, "friend_presence:#{character.id}", {:friend_presence, data})
    end
  end

  # TODO
  defp notify_party_presence(_party) do
  end
end
