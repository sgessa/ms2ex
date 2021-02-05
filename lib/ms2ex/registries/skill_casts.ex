defmodule Ms2ex.Registries.SkillCasts do
  @table_name :skill_registry

  def start() do
    :ets.new(@table_name, [:public, :set, :named_table])
  end

  def get_skill_cast(cast_id) do
    case :ets.lookup(@table_name, cast_id) do
      [{_cast_id, cast} | _] -> {:ok, cast}
      _ -> :error
    end
  end

  def set_skill_cast(skill_cast) do
    true = :ets.insert(@table_name, {skill_cast.id, skill_cast})
  end
end
