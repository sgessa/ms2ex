defmodule Ms2ex.Constants do
  def get(key) do
    Application.fetch_env!(:ms2ex, :constants)[key]
  end
end
