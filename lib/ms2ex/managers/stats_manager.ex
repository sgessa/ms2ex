defmodule Ms2ex.StatsManager do
  use GenServer

  alias Ms2ex.{Character, Characters, Field, Packets, World}

  @regen_stats [:hp, :sp, :sta]

  def lookup(character), do: call(character, :lookup)

  def consume(_character, _stat, amount) when amount <= 0, do: :error

  def consume(%Character{} = character, stat, amount) do
    cast(character, {:consume, stat, amount})
  end

  def start_link(%Character{} = character) do
    GenServer.start_link(__MODULE__, character, name: process_name(character))
  end

  def init(character) do
    stats = Characters.get_stats(character)

    {:ok,
     %{
       character_id: character.id,
       regen_sp?: false,
       regen_sta?: false,
       stats: stats
     }}
  end

  def handle_call(:lookup, _from, state) do
    {:reply, {:ok, state.stats}, state}
  end

  def handle_cast({:consume, stat_id, amount}, state) do
    cur = Map.get(state.stats, :"#{stat_id}_cur")
    amount = min(cur, amount)
    stats = Map.put(state.stats, :"#{stat_id}_cur", cur - amount)

    if stat_id in @regen_stats && !Map.get(state, :"regen_#{stat_id}?") do
      intval = Map.get(state.stats, :"#{stat_id}_regen_time_cur")
      Process.send_after(self(), {:regen, stat_id}, intval)
    end

    {:noreply, %{state | stats: stats}}
  end

  def handle_info({:regen, stat_id}, state) do
    intval = Map.get(state.stats, :"#{stat_id}_regen_time_cur")
    cur = Map.get(state.stats, :"#{stat_id}_cur")
    max = Map.get(state.stats, :"#{stat_id}_max")

    if cur < max do
      # TODO check if regen enabled

      state = %{state | stats: regen(state.stats, stat_id)}
      {:ok, character} = World.get_character(state.character_id)
      Field.broadcast(character, Packets.Stats.update(character, state.stats, [stat_id]))

      Process.send_after(self(), {:regen, stat_id}, intval)

      {:noreply, Map.put(state, :"regen_#{stat_id}?", true)}
    else
      {:noreply, Map.put(state, :"regen_#{stat_id}?", false)}
    end
  end

  defp regen(stats, stat_id) do
    stat_cur = Map.get(stats, :"#{stat_id}_cur")
    stat_max = Map.get(stats, :"#{stat_id}_max")
    regen = Map.get(stats, :"#{stat_id}_regen_cur")

    post_regen = stat_max |> min(stat_cur + regen) |> max(0)
    Map.put(stats, :"#{stat_id}_cur", post_regen)
  end

  defp call(character, msg), do: GenServer.call(process_name(character), msg)
  defp cast(character, msg), do: GenServer.cast(process_name(character), msg)

  defp process_name(character), do: :"stats:#{character.id}"
end
