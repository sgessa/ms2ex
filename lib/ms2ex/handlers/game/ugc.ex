defmodule Ms2ex.GameHandlers.Ugc do
  require Logger

  alias Ms2ex.Context
  alias Ms2ex.Enums
  alias Ms2ex.Managers
  alias Ms2ex.Net
  alias Ms2ex.Packets
  alias Ms2ex.Schema
  alias Ms2ex.Storage
  alias Ms2ex.Types

  import Packets.PacketReader
  import Net.SenderSession, only: [push: 2]

  @upload 0x01
  @confirmation 0x03
  @profile_picture 0x0B
  @load_banners 0x12
  @reserve_banner 0x13

  @design_types [:item, :furniture, :mount]

  @currencies %{meso: :mesos, meret: :merets, red_meret: :game_merets}
  @account_currencies [:merets, :game_merets]

  def handle(packet, session) do
    {command, packet} = get_byte(packet)
    handle_command(command, packet, session)
  end

  defp handle_command(@upload, packet, session) do
    {_unknown, packet} = get_long(packet)
    {info, packet} = get_info(packet)
    {_unknown, packet} = get_long(packet)
    {_unknown, packet} = get_int(packet)
    {_unknown, packet} = get_short(packet)
    {_unknown, packet} = get_short(packet)

    handle_upload(info.type, packet, session)
  end

  defp handle_command(@confirmation, packet, session) do
    {info, packet} = get_info(packet)
    {_unknown, packet} = get_int(packet)
    {resource_id, packet} = get_long(packet)
    {_file_name, packet} = get_ustring(packet)
    {_unknown, _packet} = get_short(packet)

    if info.account_id == session.account.id and info.character_id == session.character_id and
         resource_id != 0 do
      confirm(resource_id, info.type, session)
    else
      Logger.warning(
        "Rejecting UGC confirmation for account #{info.account_id} character #{info.character_id}"
      )

      session
    end
  end

  defp handle_command(@profile_picture, packet, session) do
    {url, _packet} = get_ustring(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, character} <- Context.Characters.update(character, %{profile_url: url}) do
      Managers.Character.call(character.id, {:update, character})
      Context.Field.broadcast(character, Packets.Ugc.profile_picture(character))
    end

    session
  end

  defp handle_command(@load_banners, _packet, session) do
    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         banners when is_list(banners) <- Context.Field.banners(character) do
      push(session, Packets.Ugc.load_banners(banners))
    else
      _ -> session
    end
  end

  defp handle_command(@reserve_banner, packet, session) do
    {banner_id, packet} = get_long(packet)
    {count, packet} = get_int(packet)

    with true <- count in 0..24,
         {:ok, reservations} <- read_banner_reservations(packet, count),
         {:ok, character} <- Managers.Character.lookup(session.character_id),
         {:ok, slots} <- Context.Field.reserve_banner_slots(character, banner_id, reservations) do
      push(session, Packets.Ugc.reserve_banner_slots(banner_id, slots))
    else
      _ ->
        Logger.warning("Cannot reserve UGC banner slots for banner #{banner_id}")
        session
    end
  end

  defp handle_command(command, _packet, session) do
    Logger.warning("Unhandled UGC command #{inspect(command, base: :hex)}")
    session
  end

  # Design uploads charge the player up front and hold the item until the client
  # has posted the design to the web server and confirmed it.
  defp handle_upload(type, packet, session) when type in @design_types do
    {_item_uid, packet} = get_long(packet)
    {item_id, packet} = get_int(packet)
    {_amount, packet} = get_int(packet)
    {name, packet} = get_ustring(packet)
    {_unknown, packet} = get_byte(packet)
    {_cost, packet} = get_long(packet)
    {_use_voucher, _packet} = get_bool(packet)

    with {:ok, character} <- Managers.Character.lookup(session.character_id),
         design when not is_nil(design) <- Storage.Tables.UgcDesign.get(item_id),
         {:ok, item} <- design_item(item_id, design),
         :ok <- ensure_free_slot(character, item),
         :ok <- charge(character, design),
         {:ok, resource} <- Context.Ugc.create(character.id, type) do
      item = Map.put(item, :ugc, look(resource, character, name))

      Managers.Character.call(character.id, {:stage_ugc_item, item})
      push(session, Packets.Ugc.upload(resource))
    else
      _ ->
        Logger.warning("Cannot start UGC design upload for item #{item_id}")
        session
    end
  end

  defp handle_upload(:banner, packet, session) do
    {banner_id, packet} = get_long(packet)
    {count, packet} = get_byte(packet)

    with true <- count in 1..24,
         {:ok, reservations} <- read_banner_reservations(packet, count),
         :ok <- validate_banner_reservations(reservations),
         {:ok, character} <- Managers.Character.lookup(session.character_id),
         banner when not is_nil(banner) <- Storage.Tables.Banners.get(banner_id),
         {:ok, price} <- banner_price(banner, reservations),
         :ok <- charge_banner(character, price),
         {:ok, resource} <- Context.Ugc.create(character.id, :banner),
         {:ok, _banner} <-
           Context.Field.attach_banner(
             character,
             banner_id,
             slot_ids(reservations),
             look(resource, character, "AD Banner #{banner_id}")
           ) do
      push(session, Packets.Ugc.upload(resource))
    else
      _ ->
        Logger.warning("Cannot start UGC banner upload for banner #{banner_id}")
        session
    end
  end

  defp handle_upload(type, _packet, session) when type in [:guild_emblem, :guild_banner] do
    # TODO: guild marks still need their owning systems
    case Context.Ugc.create(session.character_id, type) do
      {:ok, resource} -> push(session, Packets.Ugc.upload(resource))
      {:error, _changeset} -> session
    end
  end

  defp handle_upload(type, _packet, session) do
    # TODO: handle :layout_blueprint uploads once housing cubes exist; the
    #       payload carries the blueprint/item ids and the layout name
    Logger.warning("Unhandled UGC upload type #{inspect(type)}")
    session
  end

  defp confirm(resource_id, type, session) when type in @design_types do
    with resource when not is_nil(resource) <- Context.Ugc.get(resource_id),
         {:ok, character} <- Managers.Character.lookup(session.character_id),
         item when not is_nil(item) <- Managers.Character.call(character.id, :take_ugc_item),
         true <- item.ugc.id == resource.id,
         design when not is_nil(design) <- Storage.Tables.UgcDesign.get(item.item_id) do
      add_design_item(session, character, %{item | ugc: %{item.ugc | url: resource.path}}, %{
        design: design,
        resource: resource,
        type: type
      })
    else
      _ ->
        Logger.warning("Cannot confirm UGC resource #{resource_id}")
        session
    end
  end

  defp confirm(resource_id, type, session) do
    case Context.Ugc.get(resource_id) do
      nil ->
        Logger.warning("Cannot find UGC resource #{resource_id}")
        session

      resource when type == :banner ->
        with {:ok, character} <- Managers.Character.lookup(session.character_id),
             {:ok, banner} <- Context.Field.confirm_banner(character, resource.id, resource.path) do
          push(session, Packets.Ugc.update_banner(banner))
        else
          _ ->
            Logger.warning("Cannot confirm UGC banner resource #{resource_id}")
            session
        end

      resource ->
        Logger.warning("Unhandled UGC confirmation for #{inspect(type)}")
        push(session, Packets.Ugc.update_path(resource))
    end
  end

  defp add_design_item(session, character, item, %{
         design: design,
         resource: resource,
         type: type
       }) do
    case Managers.Inventory.add_item(character, item) do
      {:ok, {_action, added} = result} ->
        Managers.Quest.notify_item_acquired(character, added)

        session
        |> push(Packets.InventoryItem.add_item(result, character))
        |> push(
          Packets.Ugc.update_item(
            character.object_id,
            added.id,
            added,
            item.ugc,
            design.create_price,
            type
          )
        )
        |> push(Packets.Ugc.update_path(resource))

      _ ->
        Logger.error("Failed to add UGC item for resource #{resource.id}")
        session
    end
  end

  defp charge(character, %{currency_type: currency_type, create_price: price}) do
    # TODO: consume a free design coupon when the client asked to use one
    # TODO: answer with the localized lack-of-currency notice on failure
    with currency when not is_nil(currency) <- Map.get(@currencies, currency_type),
         true <- balance(character, currency) >= price,
         {:ok, _wallet} <- Context.Wallets.update(character, currency, -price) do
      :ok
    else
      _ -> :error
    end
  end

  defp charge_banner(character, price) do
    with true <- balance(character, :merets) >= price,
         {:ok, _wallet} <- Context.Wallets.update(character, :merets, -price) do
      :ok
    else
      _ -> :error
    end
  end

  # The design item lands in the outfit tab; refuse the upload while there is
  # no room for it instead of charging a player who cannot receive the item.
  defp ensure_free_slot(character, item) do
    tab = Types.Item.inventory_tab(item.metadata)

    case Managers.Inventory.find_first_available_slot(character.id, tab) do
      {:error, :full_inventory} -> :error
      _slot -> :ok
    end
  end

  defp design_item(item_id, design) do
    item = Context.Items.init(item_id, %{rarity: design.item_rarity, amount: 1})

    if item.metadata do
      {:ok, item}
    else
      :error
    end
  end

  defp balance(character, currency) when currency in @account_currencies do
    %Schema.Account{id: character.account_id}
    |> Context.Wallets.find()
    |> currency_amount(currency)
  end

  defp balance(character, currency) do
    character
    |> Context.Wallets.find()
    |> currency_amount(currency)
  end

  defp currency_amount(nil, _currency), do: 0
  defp currency_amount(wallet, currency), do: Map.get(wallet, currency, 0)

  defp look(resource, character, name) do
    %{
      id: resource.id,
      account_id: character.account_id,
      character_id: character.id,
      author: character.name,
      name: name,
      created_at: DateTime.to_unix(DateTime.utc_now()),
      url: ""
    }
  end

  defp read_banner_reservations(packet, count) do
    {reservations, _packet} =
      :reservation
      |> List.duplicate(count)
      |> Enum.reduce({[], packet}, fn _, {reservations, packet} ->
        {uid, packet} = get_long(packet)
        {_state, packet} = get_int(packet)
        {_banner_id, packet} = get_long(packet)
        {date, packet} = get_int(packet)
        {hour, packet} = get_int(packet)
        {_reserved, packet} = get_long(packet)
        {[%{id: uid, date: date, hour: hour} | reservations], packet}
      end)

    {:ok, Enum.reverse(reservations)}
  rescue
    MatchError -> :error
  end

  defp slot_ids(reservations), do: Enum.map(reservations, & &1.id)

  defp validate_banner_reservations(reservations) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    if Enum.all?(reservations, &valid_banner_reservation?(&1, now)) do
      :ok
    else
      :error
    end
  end

  defp valid_banner_reservation?(%{date: date, hour: hour}, now) when hour in 0..23 do
    with {:ok, day} <- Date.new(div(date, 10_000), rem(div(date, 100), 100), rem(date, 100)),
         {:ok, time} <- Time.new(hour, 0, 0),
         {:ok, starts_at} <- DateTime.new(day, time, "Etc/UTC") do
      DateTime.compare(starts_at, now) == :gt
    else
      _ -> false
    end
  end

  defp valid_banner_reservation?(_, _now), do: false

  defp banner_price(%{prices: prices}, reservations) do
    prices
    |> Enum.map(&normalize_price/1)
    |> sum_banner_prices(reservations)
  end

  defp banner_price(_, _reservations), do: :error

  defp sum_banner_prices(prices, reservations) do
    Enum.reduce_while(reservations, {:ok, 0}, fn %{hour: hour}, {:ok, total} ->
      add_banner_price(prices, hour, total)
    end)
  end

  defp add_banner_price(prices, hour, total) do
    case Enum.at(prices, hour) do
      price when is_integer(price) and price >= 0 -> {:cont, {:ok, total + price}}
      _ -> {:halt, :error}
    end
  end

  defp normalize_price(price) when is_integer(price), do: price
  defp normalize_price(_price), do: nil

  # Fixed-size header identifying the owner of the content being uploaded.
  defp get_info(packet) do
    {type, packet} = get_byte(packet)
    {_unknown, packet} = get_byte(packet)
    {_unknown, packet} = get_byte(packet)
    {_unknown, packet} = get_int(packet)
    {account_id, packet} = get_long(packet)
    {character_id, packet} = get_long(packet)

    {%{type: Enums.UgcType.get_key(type), account_id: account_id, character_id: character_id},
     packet}
  end
end
