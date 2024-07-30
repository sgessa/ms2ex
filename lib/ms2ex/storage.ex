defmodule Ms2ex.Storage do
  @ets_table :metadata
  @max_age :timer.hours(1)

  def get(key) do
    case :ets.lookup(@ets_table, key) do
      [{^key, {value, _}}] ->
        {:ok, value}

      [] ->
        # TODO
        # value = ...

        value = %{}
        put(key, value)

        {:ok, value}
    end
  end

  def put(key, value) do
    :ets.insert(@ets_table, {key, {value, :erlang.system_time(:millisecond)}})
    :ok
  end

  def handle_info(:cleanup, state) do
    current_time = :erlang.system_time(:millisecond)

    :ets.select_delete(@ets_table, [
      {{:"$1", {:"$2", :"$3"}}, [{:<, :"$3", current_time - @max_age}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @max_age)
  end
end
