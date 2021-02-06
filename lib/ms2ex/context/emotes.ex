defmodule Ms2ex.Emotes do
  alias Ms2ex.{Character, Emote, Repo}

  import Ecto.Query, except: [update: 2]

  @default_emotes [
    90_200_011,
    90_200_004,
    90_200_024,
    90_200_041,
    90_200_042
  ]

  def list(%Character{id: character_id}) do
    Emote
    |> where([e], e.character_id == ^character_id)
    |> select([e], e.emote_id)
    |> Repo.all()
  end

  def learn(%Character{} = character, emote_id) do
    character
    |> Ecto.build_assoc(:emotes)
    |> Emote.changeset(%{emote_id: emote_id})
    |> Repo.insert()
  end

  def default_emotes(), do: @default_emotes
end
