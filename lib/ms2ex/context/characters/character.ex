defmodule Ms2ex.Character do
  use Ecto.Schema

  alias Ms2ex.{CharacterStats, EctoTypes, Inventory, Metadata.Coord, Users}

  import Ecto.Changeset
  import EctoEnum

  @fields [
    :awakened,
    :exp,
    :gender,
    :level,
    :job,
    :map_id,
    :motto,
    :name,
    :prestige_exp,
    :prestige_level,
    :profile_url,
    :rest_exp,
    :rotation,
    :skin_color
  ]

  defenum(Gender, male: 0, female: 1)

  defenum(Job,
    none: 0,
    knight: 10,
    berseker: 20,
    wizard: 30,
    priest: 40,
    archer: 50,
    heavy_gunner: 60,
    thief: 70,
    assassin: 80,
    rune_blade: 90,
    striker: 100,
    soul_binder: 110,
    game_master: 999
  )

  schema "characters" do
    belongs_to :account, Users.Account

    has_many :equips, Inventory.Item
    has_many :inventory_items, Inventory.Item

    has_one :stats, CharacterStats

    field :awakened, :boolean, default: false

    # TODO
    field :badges, {:array, :map}, virtual: true, default: []

    # TODO
    field :clubs, {:array, :map}, virtual: true, default: []

    field :animation, :integer, virtual: true, default: 0
    field :exp, :integer, default: 0
    field :gender, Gender, default: :male
    field :guild_name, :string, virtual: true, default: "h4x0rzz"
    field :home_name, :string, virtual: true, default: ""
    field :insignia_id, :integer, virtual: true, default: 0
    field :level, :integer, default: 1
    field :job, Job
    field :map_id, :integer
    field :motto, :string, default: "Let's Maple!"
    field :mount, :map, virtual: true
    field :name, :string
    field :object_id, :integer, virtual: true, default: 0
    field :position, EctoTypes.Term, virtual: true, default: %Coord{x: 2850, y: 2550, z: 1800}
    field :prestige_exp, :integer, default: 0
    field :prestige_level, :integer, default: 1
    field :profile_url, :string, default: "http://duckduckgo.com"
    field :rest_exp, :integer, default: 0
    field :rotation, EctoTypes.Term, virtual: true, default: %Coord{x: 0, y: 0, z: 0}
    field :skin_color, EctoTypes.Term
    field :title_id, :integer, virtual: true, default: 0

    # TODO
    field :trophies, {:array, :integer}, virtual: true, default: [0, 0, 0]

    # TODO
    field :unknown_id, :integer, virtual: true, default: 0x01EF80C2

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, @fields)
    |> cast_assoc(:stats, with: &CharacterStats.changeset/2)
    |> validate_required(@fields)
    |> unique_constraint(:name)
  end

  def job_id(%{awakened: true} = char), do: real_job_id(char) * 10 + 1

  def job_id(char), do: real_job_id(char) * 10

  def real_job_id(character) do
    Keyword.get(Job.__enum_map__(), character.job)
  end
end
