defmodule Ms2ex.Metadata.Pet do
  defstruct [:id, :name, :type, :ai_presets, :npc_id, :item_slots, :enable_extraction, :option_level, :option_factor, :skill, :effect, :distance, :time]

  def id(), do: :id
end
