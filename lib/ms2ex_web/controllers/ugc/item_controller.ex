defmodule Ms2exWeb.Ugc.ItemController do
  @moduledoc "Meshes of items designed by players."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "items"

  def show(conn, %{"item_id" => item_id, "file" => file}) do
    Ugc.serve(conn, [@dir, item_id, file], "m2u", "application/octet-stream")
  end

  def store(%{id: item_id, file: file}, resource) do
    with :ok <- Ugc.store([@dir, to_string(item_id), "#{resource.id}.m2u"], file) do
      Ugc.publish(resource, "item/ms2/01/#{item_id}/#{resource.id}.m2u")
    end
  end
end
