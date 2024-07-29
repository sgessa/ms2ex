defmodule Ms2ex.Metadata.Achievement do
  defstruct [:id, :name, :account_wide, :category, :category_tags, :grades]

  def ids(), do: [:id]
end
