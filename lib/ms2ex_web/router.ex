defmodule Ms2exWeb.Router do
  use Ms2exWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :ugc do
    plug :put_secure_browser_headers
  end

  scope "/api", Ms2exWeb do
    pipe_through :api
  end

  # Every HTTP call the game client makes is resolved against the base url it is
  # handed at login, so they all share this prefix.
  scope "/ugc", Ms2exWeb do
    pipe_through :ugc

    post "/irrq.aspx", ClientController, :rankings
    post "/ruq.aspx", ClientController, :info
  end

  scope "/ugc", Ms2exWeb.Ugc do
    pipe_through :ugc

    post "/urq.aspx", UploadController, :create

    get "/data/profiles/avatar/:character_id/:file", ProfileController, :show
    get "/item/ms2/01/:item_id/:file", ItemController, :show
    get "/itemicon/ms2/01/:item_id/:file", ItemIconController, :show
    get "/banner/ms2/01/:banner_id/:file", BannerController, :show
    get "/blueprint/ms2/01/:blueprint_id/:file", BlueprintController, :show
    get "/guildmark/ms2/01/:guild_id/banner/:file", GuildController, :banner
    get "/guildmark/ms2/01/:guild_id/:file", GuildController, :emblem
  end

  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: Ms2exWeb.Telemetry
    end
  end
end
