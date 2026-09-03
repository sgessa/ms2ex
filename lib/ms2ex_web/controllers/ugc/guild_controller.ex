defmodule Ms2exWeb.Ugc.GuildController do
  @moduledoc "Guild emblems and the posters hung in guild halls."

  use Ms2exWeb, :controller

  alias Ms2exWeb.Helpers.Ugc

  @dir "guildmark"

  def emblem(conn, %{"guild_id" => guild_id, "file" => file}) do
    Ugc.serve(conn, [@dir, guild_id, file], "png", "image/png")
  end

  def banner(conn, %{"guild_id" => guild_id, "file" => file}) do
    Ugc.serve(conn, [@dir, guild_id, "banner", file], "png", "image/png")
  end

  def store_emblem(%{id: guild_id, file: file}, resource) do
    with :ok <- Ugc.store([@dir, to_string(guild_id), "#{resource.id}.png"], file) do
      Ugc.publish(resource, "guildmark/ms2/01/#{guild_id}/#{resource.id}.png")
    end
  end

  def store_banner(%{id: guild_id, file: file}, resource) do
    with :ok <- Ugc.store([@dir, to_string(guild_id), "banner", "#{resource.id}.png"], file) do
      Ugc.publish(resource, "guildmark/ms2/01/#{guild_id}/banner/#{resource.id}.png")
    end
  end
end
