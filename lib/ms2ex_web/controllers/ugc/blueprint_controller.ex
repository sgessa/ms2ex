defmodule Ms2exWeb.Ugc.BlueprintController do
  @moduledoc "Previews of saved housing layouts."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "blueprint"

  def show(conn, %{"blueprint_id" => blueprint_id, "file" => file}) do
    Ugc.serve(conn, [@dir, blueprint_id, file], "png", "image/png")
  end

  def store_preview(%{file: file}, resource) do
    dir = to_string(resource.id)

    with :ok <- Ugc.store([@dir, dir, "#{resource.id}.png"], file) do
      Ugc.publish(resource, "blueprint/ms2/01/#{resource.id}/#{resource.id}.png")
    end
  end

  # The icon sits next to the preview and is not what the resource points at.
  def store_icon(%{file: file}, resource) do
    dir = to_string(resource.id)

    with :ok <- Ugc.store([@dir, dir, "#{resource.id}_icon.png"], file) do
      {:ok, "blueprint/ms2/01/#{resource.id}/#{resource.id}_icon.png"}
    end
  end
end
