defmodule Ms2ex.Context.Utils do
  def rand_float(min, max) do
    :rand.uniform() * (max - min) + min
  end
end
