defmodule Ms2exWeb.Ugc.ItemIconController do
  @moduledoc "Icons rendered by the client for player designed items."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "itemicon"

  def show(conn, %{"item_id" => item_id, "file" => file}) do
    Ugc.serve(conn, [@dir, item_id, file], "png", "image/png")
  end

  # The icon travels with the mesh, so the resource path keeps pointing at the mesh.
  def store(%{id: item_id, file: file}, resource) do
    with :ok <- Ugc.store([@dir, to_string(item_id), "#{resource.id}.png"], file) do
      {:ok, "itemicon/ms2/01/#{item_id}/#{resource.id}.png"}
    end
  end
end
