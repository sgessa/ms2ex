defmodule Ms2ex.InstanceFieldsTest do
  use Ms2ex.DataCase, async: true
  use Mimic

  alias Ms2ex.Managers
  alias Ms2ex.Schema
  alias Ms2ex.Storage.Tables.InstanceFields

  @tutorial_map 52_000_001
  @channel_scale_map 52_000_058
  @shared_map 2_000_000
  @quest_instance 63_000_015

  @table_doc %{
    @tutorial_map => %{type: :solo, instance_id: 1_000_011, pool_count: 0, max_count: 0},
    @channel_scale_map => %{
      type: :channel_scale,
      instance_id: 1_000_068,
      pool_count: 0,
      max_count: 20
    }
  }

  setup do
    stub_metadata(%{
      "table:server.instancefield.xml" => @table_doc,
      "map:63000015" => %{enter_return_id: 2_000_301}
    })

    :ok
  end

  test "returns the instance doc of a listed map" do
    assert %{type: :solo, instance_id: 1_000_011} = InstanceFields.get(@tutorial_map)
  end

  test "unlisted maps are not instanced" do
    assert InstanceFields.get(@shared_map) == nil
    refute InstanceFields.instanced?(@shared_map)
  end

  test "solo? holds only for solo maps" do
    assert InstanceFields.solo?(@tutorial_map)
    refute InstanceFields.solo?(@channel_scale_map)
    refute InstanceFields.solo?(@shared_map)
  end

  test "field names normalize a missing instance to the shared field" do
    assert Managers.Field.field_name(@shared_map, 1, nil) ==
             :"field:2000000:channel:1:instance:0"

    character = %Schema.Character{map_id: @shared_map, channel_id: 1}

    assert Managers.Field.field_name(character) == :"field:2000000:channel:1:instance:0"
  end

  test "field names separate instances of the same map and channel" do
    assert Managers.Field.field_name(@tutorial_map, 1, 0) ==
             :"field:52000001:channel:1:instance:0"

    assert Managers.Field.field_name(@tutorial_map, 1, 7) !=
             Managers.Field.field_name(@tutorial_map, 1, 8)
  end

  test "assign_instance keeps the pending change_map instance" do
    character = %Schema.Character{map_id: @tutorial_map, change_map: %{instance: 9}}

    assert %{field_instance: 9} = Managers.Field.assign_instance(character)
  end

  test "assign_instance keeps the current stamp while on the same field" do
    character = %Schema.Character{map_id: @tutorial_map, field_instance: 5}

    assert %{field_instance: 5} = Managers.Field.assign_instance(character)
  end

  test "assign_instance allocates for solo maps and binds shared maps to 0" do
    assert first = Managers.Field.assign_instance(%Schema.Character{map_id: @tutorial_map})
    assert second = Managers.Field.assign_instance(%Schema.Character{map_id: @tutorial_map})
    assert first.field_instance != second.field_instance

    assert %{field_instance: 0} =
             Managers.Field.assign_instance(%Schema.Character{map_id: @channel_scale_map})
  end

  test "return_map_id falls back to the map itself" do
    assert Managers.Field.return_map_id(@tutorial_map) == @tutorial_map
    assert Managers.Field.return_map_id(@quest_instance) == 2_000_301
  end

  test "solo maps allocate a fresh instance id per entry, others share" do
    assert first = Managers.Field.instance_id(@tutorial_map)
    assert second = Managers.Field.instance_id(@tutorial_map)
    assert first != second

    assert Managers.Field.instance_id(@channel_scale_map) == 0
    assert Managers.Field.instance_id(@shared_map) == 0
  end
end
