defmodule Ms2ex.GameHandlers.Helper.Session do
  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Net.SenderSession
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Phoenix.PubSub

  def init_character(%Schema.Character{} = character) do
    for %{status: :accepted, is_request: false, rcpt_id: rcpt_id} <- character.friends do
      Context.Friends.subscribe(character, rcpt_id)
    end

    notify_friend_presence(character)

    if character.party_id do
      notify_party_presence(character)
      SenderSession.run(character, fn -> Managers.PartyServer.subscribe(character.party_id) end)
    end
  end

  def cleanup(character) do
    character = %{character | online?: false}
    Managers.Inventory.stop(character)
    Managers.Quest.stop(character.id)
    Context.Field.leave(character)
    notify_party_presence(character)
    notify_friend_presence(character)
    leave_group_chats(character)
  end

  defp leave_group_chats(character) do
    Enum.each(character.group_chat_ids, fn chat_id ->
      {:ok, chat} = Managers.GroupChat.remove_member(%Managers.GroupChat{id: chat_id}, character)
      Managers.GroupChat.broadcast(chat.id, Packets.GroupChat.leave_notice(chat, character))
    end)
  end

  defp notify_friend_presence(character) do
    for friend <- character.friends do
      data = %{character: character, shared_id: friend.shared_id}
      PubSub.broadcast(Ms2ex.PubSub, "friend_presence:#{character.id}", {:friend_presence, data})
    end
  end

  defp notify_party_presence(%{online?: true} = character) do
    Managers.PartyServer.broadcast(character.party_id, Packets.Party.login_notice(character))
  end

  defp notify_party_presence(character) do
    Managers.PartyServer.member_offline(character)
  end
end
