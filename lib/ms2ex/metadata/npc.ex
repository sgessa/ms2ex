defmodule Ms2ex.Metadata.Npc do
  defstruct [:id, :name, :ai_path, :model, :stat, :basic, :distance, :skill, :property, :drop_info, :action, :dead]

  def ids(), do: [:id]
end
