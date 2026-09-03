defmodule Ms2exWeb.Ugc.ProfileController do
  @moduledoc "Character profile pictures."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "profiles"

  def show(conn, %{"character_id" => character_id, "file" => file}) do
    Ugc.serve(conn, [@dir, character_id, file], "png", "image/png")
  end

  @doc """
  Profile pictures are not backed by a resource row: the client picks the path
  straight out of the response. Only the newest picture is kept.
  """
  def store(%{character_id: character_id, file: file}) do
    dir = to_string(character_id)
    name = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

    Ugc.clear([@dir, dir])

    with :ok <- Ugc.store([@dir, dir, "#{name}.png"], file) do
      {:ok, "data/profiles/avatar/#{character_id}/#{name}.png"}
    end
  end
end
