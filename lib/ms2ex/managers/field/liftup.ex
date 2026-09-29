defmodule Ms2ex.Managers.Field.Liftup do
  @moduledoc """
  Liftable object weapons (barrels, crates, pots): the player picks one up
  with the interact key, the held object replaces the castable skills with
  the throw skill granted by the rolled item, and the throw releases it.
  The weapon sits back on its tile after its respawn delay, and a hostile
  npc may burst out of the container on lift.
  """

  alias Ms2ex.Managers
  alias Ms2ex.Packets
  alias Ms2ex.Storage
  alias Ms2ex.Types

  @grid_size 150


  # ugc-map error codes carried by the response-cube error notice
  def no_cube_to_lift, do: 37
  def not_allowed_item, do: 95

  def init_liftups(state) do
    weapons =
      state.map_id
      |> Storage.Maps.get_object_weapons()
      |> Map.new(fn weapon -> {grid_key(weapon.position), weapon} end)

    state
    |> Map.put(:object_weapons, weapons)
    |> Map.put(:held_liftups, %{})
  end

  @doc """
  The player lifts the object weapon at a grid tile. One of the weapon's
  item ids is rolled (rotating with the shared tick), the item's metadata
  grants the throw skill, and the respawn delay is reported to clients so
  the container visual returns on time.

  Returns `{state, :ok}` or `{state, {:error, code}}` for the error notice.
  """
  def liftup(state, character_id, grid) do
    with :ok <- ensure_empty_handed(state, character_id),
         {:ok, weapon} <- Map.fetch(state.object_weapons, grid),
         {:ok, liftup} <- roll_weapon(weapon) do
      {:ok, character} = Managers.Character.call(character_id, :lookup)

      state = put_in(state, [:held_liftups, character_id], liftup)

      respawn_at = Ms2ex.sync_ticks() + weapon.respawn_tick

      Managers.Field.broadcast(
        state.topic,
        Packets.ResponseCube.pickup(character, liftup.item_id, grid, respawn_at)
      )

      # holding a thrown object is combat: the stance holds through the
      # battle quiet window like any in-battle cast
      Managers.Field.broadcast(state.topic, Packets.UserBattle.set_stance(character, true))
      state = Managers.Field.BattleStance.arm(state, character)

      maybe_spawn_ambush(state, weapon)
      {state, :ok}
    else
      :held -> {state, {:error, not_allowed_item()}}
      :error -> {state, {:error, no_cube_to_lift()}}
    end
  end

  @doc """
  The player drops the held object weapon without throwing it: the hold
  clears and clients release the carry pose.
  """
  def drop(state, character_id) do
    if Map.has_key?(state.held_liftups, character_id) do
      {:ok, character} = Managers.Character.call(character_id, :lookup)

      state = Map.put(state, :held_liftups, Map.delete(state.held_liftups, character_id))
      Managers.Field.broadcast(state.topic, Packets.ResponseCube.drop(character))
      {state, :ok}
    else
      {state, :error}
    end
  end

  @doc """
  Cast gate while holding an object weapon: only the held object's throw
  skill casts (and consumes the hold), every other skill is refused.
  """
  def use_skill(state, character_id, skill_id, skill_level) do
    case Map.get(state.held_liftups, character_id) do
      %{skill_id: held_skill_id, skill_level: held_skill_level}
      when held_skill_id == skill_id and held_skill_level == skill_level ->
        state = Map.put(state, :held_liftups, Map.delete(state.held_liftups, character_id))
        {state, :ok}

      %{skill_id: _} ->
        {state, :error}

      nil ->
        {state, :ok}
    end
  end

  # the character leaves the field (or the field dies): the hold clears
  # without a broadcast — the carry pose vanishes with the player entity
  def release(state, character_id) do
    Map.put(state, :held_liftups, Map.delete(state.held_liftups, character_id))
  end

  defp ensure_empty_handed(state, character_id) do
    if Map.has_key?(state.held_liftups, character_id), do: :held, else: :ok
  end

  defp roll_weapon(weapon) do
    item_id = Enum.at(weapon.item_ids, rem(Ms2ex.sync_ticks(), length(weapon.item_ids)))

    case Storage.Items.get_meta(item_id) do
      %{skill_weapon_id: skill_weapon_id, skill_weapon_level: skill_weapon_level}
      when skill_weapon_id > 0 ->
        {:ok,
         %{
           item_id: item_id,
           skill_id: skill_weapon_id,
           skill_level: skill_weapon_level,
           grid: grid_key(weapon.position)
         }}

      _ ->
        :error
    end
  end

  # breaking a container open may release its hidden occupant
  defp maybe_spawn_ambush(state, weapon) do
    if weapon.spawn_npc_id != 0 and :rand.uniform() < weapon.spawn_npc_rate do
      {_field_npc, state} =
        Managers.Field.Npc.spawn_npc(state, weapon.spawn_npc_id, %{
          position: weapon.position,
          rotation: weapon.rotation
        })

      state
    else
      state
    end
  end

  defp grid_key(%Types.Coord{x: x, y: y, z: z}) do
    {grid_coord(x), grid_coord(y), grid_coord(z)}
  end

  defp grid_coord(value) when is_number(value), do: round(value / @grid_size)
  defp grid_coord(_), do: 0
end
