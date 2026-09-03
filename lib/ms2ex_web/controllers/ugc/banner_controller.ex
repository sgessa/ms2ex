defmodule Ms2exWeb.Ugc.BannerController do
  @moduledoc "Artwork displayed on field advertising banners."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "banner"

  def show(conn, %{"banner_id" => banner_id, "file" => file}) do
    Ugc.serve(conn, [@dir, banner_id, file], "m2u", "application/octet-stream")
  end

  def store(%{id: banner_id, file: file}, resource) do
    with :ok <- Ugc.store([@dir, to_string(banner_id), "#{resource.id}.m2u"], file) do
      Ugc.publish(resource, "banner/ms2/01/#{banner_id}/#{resource.id}.m2u")
    end
  end
end
