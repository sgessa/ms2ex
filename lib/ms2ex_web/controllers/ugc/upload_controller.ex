defmodule Ms2exWeb.Ugc.UploadController do
  @moduledoc """
  Single entry point the game client posts every kind of user generated content
  to. The type in the envelope decides which resource the payload belongs to.
  """

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers
  alias Ms2exWeb.Ugc

  def create(conn, _params) do
    case Helpers.Ugc.read_upload(conn) do
      {:ok, upload} -> Helpers.Ugc.send_path(conn, store(upload))
      {:error, reason} -> Helpers.Ugc.send_error(conn, reason)
    end
  end

  defp store(%{type: :profile_avatar} = upload), do: Ugc.ProfileController.store(upload)

  defp store(%{type: type} = upload) do
    with {:ok, resource} <- Helpers.Ugc.owned_resource(upload) do
      store(type, upload, resource)
    end
  end

  defp store(type, upload, resource) when type in [:item, :furniture, :mount] do
    Ugc.ItemController.store(upload, resource)
  end

  defp store(:item_icon, upload, resource), do: Ugc.ItemIconController.store(upload, resource)
  defp store(:banner, upload, resource), do: Ugc.BannerController.store(upload, resource)

  defp store(:guild_emblem, upload, resource) do
    Ugc.GuildController.store_emblem(upload, resource)
  end

  defp store(:guild_banner, upload, resource) do
    Ugc.GuildController.store_banner(upload, resource)
  end

  defp store(:layout_blueprint, upload, resource) do
    Ugc.BlueprintController.store_preview(upload, resource)
  end

  defp store(:blueprint_icon, upload, resource) do
    Ugc.BlueprintController.store_icon(upload, resource)
  end

  defp store(_type, _upload, _resource), do: {:error, :unsupported}
end
