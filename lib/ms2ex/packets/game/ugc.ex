defmodule Ms2ex.Packets.Ugc do
  alias Ms2ex.Enums

  import Ms2ex.Packets.PacketWriter

  @upload 0x02
  @update_path 0x04
  @enable_banner 0x07
  @profile_picture 0x0B
  @update_banner 0x08
  @update_item 0x0D
  @update_furnishing 0x0E
  @update_mount 0x0F
  @update_layout_blueprint 0x10
  @set_endpoint 0x11
  @load_banner 0x12
  @reserve_banners 0x14

  @doc """
  Tells the client which host to upload user generated content to and where to
  fetch it back from.
  """
  def set_endpoint() do
    config = Application.get_env(:ms2ex, Ms2ex)

    __MODULE__
    |> build()
    |> put_byte(@set_endpoint)
    |> put_ustring(config[:ugc].endpoint)
    |> put_ustring(config[:ugc].resource)
    |> put_ustring(config[:ugc].locale)
    |> put_byte(0x2)
  end

  @doc """
  Acknowledges an announced upload. The client uses the returned id as the file
  name when it posts the payload to the web server.
  """
  def upload(resource) do
    __MODULE__
    |> build()
    |> put_byte(@upload)
    |> put_ecto_enum(Enums.UgcType, resource.type)
    |> put_long(resource.id)
    |> put_ustring(to_string(resource.id))
  end

  @doc "Points the client at the stored file once the upload completed."
  def update_path(resource) do
    __MODULE__
    |> build()
    |> put_byte(@update_path)
    |> put_ecto_enum(Enums.UgcType, resource.type)
    |> put_long(resource.id)
    |> put_ustring(resource.path)
  end

  def profile_picture(character) do
    __MODULE__
    |> build()
    |> put_byte(@profile_picture)
    |> put_int(Map.get(character, :object_id) || 0)
    |> put_long(character.id)
    |> put_ustring(character.profile_url)
  end

  def update_item(object_id, item_uid, item, look, create_price, type) do
    __MODULE__
    |> build()
    |> put_byte(item_command(type))
    |> put_int(object_id)
    |> put_long(item_uid)
    |> put_int(item.item_id)
    |> put_int(item.amount)
    |> put_ustring(look.name)
    |> put_byte(1)
    |> put_long(create_price)
    |> put_byte()
    |> put_ugc(look)
  end

  def update_layout_blueprint(object_id, blueprint_uid, item, look) do
    __MODULE__
    |> build()
    |> put_byte(@update_layout_blueprint)
    |> put_int(object_id)
    |> put_long(blueprint_uid)
    |> put_long(item.id)
    |> put_int(item.item_id)
    |> put_ustring(look.name)
    |> put_ugc(look)
  end

  @doc """
  Advertising banners placed on the field: rolling images, the slot currently
  displayed on each banner and the reservation schedule per banner.
  """
  def load_banners(banners \\ []) do
    __MODULE__
    |> build()
    |> put_byte(@load_banner)
    |> put_int(0)
    |> put_int(length(banners))
    # TODO: write the active slot once banner reservations are stored
    |> reduce(banners, fn banner, packet ->
      case Enum.find(banner.slots, & &1.active) do
        nil ->
          packet
          |> put_long(banner.id)
          |> put_bool(false)

        slot ->
          packet
          |> put_long(banner.id)
          |> put_bool(true)
          |> put_active_banner_slot(slot)
      end
    end)
    |> put_int(length(banners))
    |> reduce(banners, fn banner, packet ->
      packet
      |> put_long(banner.id)
      |> put_int(length(banner.slots))
      |> reduce(banner.slots, fn slot, packet ->
        packet
        |> put_long(slot.date * 100_000 + slot.hour)
        |> put_ustring(get_in(slot, [:ugc, :author]) || "")
        |> put_bool(true)
      end)
    end)
  end

  def reserve_banner_slots(banner_id, slots) do
    __MODULE__
    |> build()
    |> put_byte(@reserve_banners)
    |> put_long(banner_id)
    |> put_int(length(slots))
    |> reduce(slots, fn slot, packet ->
      packet
      |> put_long(slot.id)
      |> put_int(if(slot.active, do: 2, else: 1))
      |> put_long(slot.banner_id)
      |> put_int(slot.date)
      |> put_int(slot.hour)
      |> put_long()
    end)
  end

  def activate_banner(banner) do
    active_slot = Enum.find(banner.slots, & &1.active)

    __MODULE__
    |> build()
    |> put_byte(@enable_banner)
    |> put_long(banner.id)
    |> put_active_banner(active_slot)
  end

  defp put_active_banner(packet, nil), do: put_bool(packet, false)

  defp put_active_banner(packet, slot),
    do: packet |> put_bool(true) |> put_active_banner_slot(slot)

  def update_banner(banner) do
    __MODULE__
    |> build()
    |> put_byte(@update_banner)
    |> put_long(banner.id)
    |> put_int(length(banner.slots))
    |> reduce(banner.slots, fn slot, packet ->
      packet
      |> put_long(slot.date * 100_000 + slot.hour)
      |> put_ustring(get_in(slot, [:ugc, :author]) || "")
      |> put_bool(true)
    end)
  end

  defp put_active_banner_slot(packet, slot) do
    packet
    |> put_ecto_enum(Enums.UgcType, :banner)
    |> put_int(2)
    |> put_long(slot.ugc.account_id)
    |> put_long(slot.ugc.character_id)
    |> put_ustring()
    |> put_ustring(slot.ugc.author)
    |> put_long(slot.ugc.id)
    |> put_ustring(to_string(slot.ugc.id))
    |> put_byte(3)
    |> put_byte(1)
    |> put_long(slot.banner_id)
    |> put_byte(1)
    |> put_long(slot.id)
    |> put_int(2)
    |> put_long(slot.banner_id)
    |> put_int(slot.date)
    |> put_int(slot.hour)
    |> put_long()
    |> put_ustring(slot.ugc.url)
  end

  @doc """
  Appends a user generated content descriptor. Items without one still need the
  fields written, so `nil` writes an empty descriptor.
  """
  def put_ugc(packet, look \\ nil)

  def put_ugc(packet, nil) do
    packet
    |> put_long()
    |> put_ustring()
    |> put_ustring()
    # the client only renders the custom icon when this is set
    |> put_byte(1)
    |> put_int(1)
    |> put_long()
    |> put_long()
    |> put_ustring()
    |> put_long()
    |> put_ustring()
    |> put_byte()
  end

  def put_ugc(packet, look) do
    packet
    |> put_long(look.id)
    |> put_ustring(to_string(look.id))
    |> put_ustring(look.name)
    # the client only renders the custom icon when this is set
    |> put_byte(1)
    |> put_int(1)
    |> put_long(look.account_id)
    |> put_long(look.character_id)
    |> put_ustring(look.author)
    |> put_long(look.created_at)
    |> put_ustring(look.url)
    |> put_byte()
  end

  defp item_command(:furniture), do: @update_furnishing
  defp item_command(:mount), do: @update_mount
  defp item_command(_type), do: @update_item
end
