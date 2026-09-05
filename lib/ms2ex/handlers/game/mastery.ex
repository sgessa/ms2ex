defmodule Ms2ex.GameHandlers.Mastery do
  @moduledoc """
  Life skill requests: claiming the reward box of a mastery grade and
  crafting a mastery recipe at a workbench.
  """

  alias Ms2ex.Context
  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage

  import Ms2ex.Net.SenderSession, only: [push: 2]
  import Ms2ex.Packets.PacketReader

  @reward 0x1
  @craft 0x2

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    handle_command(command, packet, session)
  end

  defp handle_command(@reward, packet, session) do
    {reward_box_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, _character, item} <- Context.Mastery.claim_reward(character, reward_box_id) do
      push(session, Packets.Mastery.claim_reward(reward_box_id, [item]))
    else
      {:error, error} -> push(session, Packets.Mastery.error(error))
      _ -> session
    end
  end

  defp handle_command(@craft, packet, session) do
    {recipe_id, _packet} = get_int(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, recipe} <- Storage.Tables.MasteryRecipes.lookup(recipe_id),
         {:ok, _character} <- Context.Mastery.craft(character, recipe_id) do
      push(session, Packets.Mastery.get_crafted_item(recipe.type, crafted(recipe)))
    else
      {:error, error} -> push(session, Packets.Mastery.error(error))
      _ -> session
    end
  end

  defp handle_command(_command, _packet, session), do: session

  defp crafted(recipe) do
    Enum.map(recipe.reward_items, &%{item_id: &1.item_id, rarity: &1.rarity})
  end
end
