defmodule Ms2ex.ProtoMetadata.SkillType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :attack, 1
  field :unknown, 2
  field :gm, 3
end

defmodule Ms2ex.ProtoMetadata.SkillDamageType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :physical, 1
  field :magic, 2
  field :unknown, 3
end

defmodule Ms2ex.ProtoMetadata.SubSkillType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :unknown, 1
  field :status, 2
  field :unknown2, 3
  field :unknown3, 4
  field :gm, 5
  field :global, 6
  field :unknown4, 7
  field :unknown5, 8
  field :unknown6, 9
end

defmodule Ms2ex.ProtoMetadata.BuffType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :buff, 1
  field :debuff, 2
  field :unknown, 3
end

defmodule Ms2ex.ProtoMetadata.SubBuffType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :none, 0
  field :owner, 1
  field :entity, 2
  field :element, 4
  field :shield, 6
  field :crowd_control, 8
  field :recovery, 16
  field :unknown2, 32
  field :unknown3, 64
  field :unknown4, 128
  field :unknown5, 256
  field :unknown6, 512
  field :unknown7, 1024
end

defmodule Ms2ex.ProtoMetadata.SkillAttack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :attack_point, 1, type: :int32
  field :target_count, 2, type: :int32
  field :magic_path_id, 3, type: :int32
  field :cube_magic_path_id, 4, type: :int32
end

defmodule Ms2ex.ProtoMetadata.SkillData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :duration, 1, type: :int32
  field :buff_type, 2, enum: true, type: Ms2ex.ProtoMetadata.BuffType
  field :sub_buff_type, 3, enum: true, type: Ms2ex.ProtoMetadata.SubBuffType
  field :buff_category, 4, type: :int32
  field :event_buff_type, 5, type: :int32
  field :max_stacks, 6, type: :int32
  field :keep_condition, 7, type: :int32
end

defmodule Ms2ex.ProtoMetadata.SkillMotion do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :sequence_name, 1, type: :string
  field :effect, 2, type: :string
end

defmodule Ms2ex.ProtoMetadata.SkillCondition do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :level, 2, type: :int32
  field :splash, 3, type: :bool
  field :target, 4, type: :int32
  field :owner, 5, type: :int32
end

defmodule Ms2ex.ProtoMetadata.SkillUpgrade do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :level_required, 1, type: :int32
  field :skills_required, 2, type: :int32, repeated: true
  field :skill_levels_required, 3, type: :int32, repeated: true
end

defmodule Ms2ex.ProtoMetadata.SkillLevel do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :level, 1, type: :int32
  field :spirit, 2, type: :int32
  field :stamina, 3, type: :int32
  field :damage_rate, 4, type: :float
  field :feature, 5, type: :string
  field :motion, 6, type: Ms2ex.ProtoMetadata.SkillMotion
  field :attacks, 7, type: Ms2ex.ProtoMetadata.SkillAttack, repeated: true
  field :conditions, 8, repeated: true, type: Ms2ex.ProtoMetadata.SkillCondition
  field :data, 9, type: Ms2ex.ProtoMetadata.SkillData
  field :skill_upgrade, 10, type: Ms2ex.ProtoMetadata.SkillUpgrade
end

defmodule Ms2ex.ProtoMetadata.Skill do
  @moduledoc false
  use Protobuf, syntax: :proto3

  field :id, 1, type: :int32
  field :skill_levels, 2, repeated: true, type: Ms2ex.ProtoMetadata.SkillLevel
  field :sub_skills, 3, repeated: true, type: :int32
  field :job, 4, type: Ms2ex.ProtoMetadata.Job, enum: true
  field :starting_level, 5, type: :int32
  field :state, 6, type: :string
  field :damage_type, 7, enum: true, type: Ms2ex.ProtoMetadata.SkillDamageType
  field :type, 8, enum: true, type: Ms2ex.ProtoMetadata.SkillType
  field :sub_type, 9, enum: true, type: Ms2ex.ProtoMetadata.SubSkillType
  field :element, 10, type: :int32
  field :super_armor, 11, type: :bool
  field :sp_recovery?, 12, type: :bool
  field :max_level, 13, type: :int32
end

defmodule Ms2ex.ProtoMetadata.Skills do
  @moduledoc false
  use Protobuf, syntax: :proto3

  alias Ms2ex.ProtoMetadata.Skill

  field :items, 1, repeated: true, type: Skill

  @table :skill_metadata

  def store() do
    list =
      [:code.priv_dir(:ms2ex), "resources", "ms2-skill-metadata"]
      |> Path.join()
      |> File.read!()
      |> __MODULE__.decode()

    :ets.new(@table, [:protected, :set, :named_table])

    for %{id: item_id} = metadata <- list.items do
      :ets.insert(@table, {item_id, metadata})
    end
  end

  def get(skill_id) do
    case :ets.lookup(@table, skill_id) do
      [{_id, %Skill{} = meta}] -> meta
      _ -> nil
    end
  end

  def get_level(%Skill{skill_levels: levels}, lvl) do
    Enum.find(levels, &(&1.level == lvl))
  end
end
