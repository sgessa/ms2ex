defmodule Ms2ex.Packets.UserEnv do
  import Ms2ex.Packets.PacketWriter

  @modes %{
    start_list: 0x0,
    update_title: 0x1,
    set_titles: 0x2,
    end_list: 0x4,
    interacted_objects: 0x4,
    gathering_counts: 0x8,
    mastery_rewards_claimed: 0x9
  }

  @doc "Interact objects the character already used (telescopes, ...)."
  def interacted_objects(object_ids) do
    __MODULE__
    |> build()
    |> put_byte(@modes.interacted_objects)
    |> put_int(length(object_ids))
    |> reduce(object_ids, fn object_id, packet -> put_int(packet, object_id) end)
  end

  def update_title(character) do
    __MODULE__
    |> build()
    |> put_byte(@modes.update_title)
    |> put_int(character.object_id)
    |> put_int(character.title_id)
  end

  def set_titles(titles) do
    __MODULE__
    |> build()
    |> put_byte(@modes.set_titles)
    |> put_int(length(titles))
    |> reduce(titles, fn title_id, packet ->
      put_int(packet, title_id)
    end)
  end

  def item_collects(item_collects \\ %{}) do
    __MODULE__
    |> build()
    |> put_byte(0x03)
    |> put_int(map_size(item_collects))
    |> reduce(item_collects, fn {item_id, quantity}, packet ->
      packet
      |> put_int(item_id)
      |> put_byte(quantity)
    end)
  end

  @doc "How often each gathering recipe was already harvested."
  def gathering_counts(counts) do
    __MODULE__
    |> build()
    |> put_byte(@modes.gathering_counts)
    |> put_int(map_size(counts))
    |> reduce(counts, fn {recipe_id, count}, packet ->
      packet
      |> put_int(recipe_id)
      |> put_int(count)
    end)
    |> put_int()
  end

  @doc "Mastery grade reward boxes the character already claimed."
  def mastery_rewards_claimed(claimed) do
    __MODULE__
    |> build()
    |> put_byte(@modes.mastery_rewards_claimed)
    |> put_int(map_size(claimed))
    |> reduce(claimed, fn {reward_box_id, _claimed?}, packet ->
      packet
      |> put_int(reward_box_id)
      |> put_bool(true)
    end)
  end

  def set_mode(mode, integers \\ 1) do
    __MODULE__
    |> build()
    |> put_byte(mode)
    |> put_zeroes(integers)
  end

  defp put_zeroes(packet, integers) when integers > 0 do
    packet
    |> put_int()
    |> put_zeroes(integers - 1)
  end

  defp put_zeroes(packet, _integers), do: packet
end
