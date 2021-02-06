defmodule Ms2ex.Character do
  use Ecto.Schema

  alias Ms2ex.{EctoTypes, Inventory, Metadata.Coord}

  import Ecto.Changeset
  import EctoEnum

  @max_level 70

  @fields [
    :awakened,
    :exp,
    :gender,
    :insignia_id,
    :level,
    :job,
    :map_id,
    :motto,
    :name,
    :prestige_exp,
    :prestige_level,
    :rest_exp,
    :skin_color,
    :title_id
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
    belongs_to :account, Ms2ex.Account

    has_many :equips, Inventory.Item
    has_many :inventory_items, Inventory.Item

    has_many :hot_bars, Ms2ex.HotBar
    has_many :skill_tabs, Ms2ex.SkillTab
    has_many :titles, Ms2ex.CharacterTitle

    has_one :stats, Ms2ex.CharacterStats
    has_one :wallet, Ms2ex.Wallet

    field :awakened, :boolean, default: false

    # TODO
    field :badges, {:array, :map}, virtual: true, default: []

    # TODO
    field :clubs, {:array, :map}, virtual: true, default: []

    # TODO
    field :trophies, {:array, :integer}, virtual: true, default: [0, 0, 0]

    field :animation, :integer, virtual: true, default: 0
    field :exp, :integer, default: 0
    field :gender, Gender, default: :male
    field :guild_name, :string, virtual: true, default: "h4x0rzz"
    field :home_name, :string, virtual: true, default: ""
    field :insignia_id, :integer, default: 0
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
    field :profile_url, :string, default: ""
    field :rest_exp, :integer, default: 0
    field :rotation, EctoTypes.Term, virtual: true, default: %Coord{x: 0, y: 0, z: 0}
    field :skin_color, EctoTypes.Term
    field :title_id, :integer, default: 0

    # TODO
    field :unknown_id, :integer, virtual: true, default: 0x01EF80C2

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(character, attrs) do
    character
    |> cast(attrs, @fields)
    |> cast_assoc(:hot_bars, with: &Ms2ex.HotBar.changeset/2)
    |> cast_assoc(:skill_tabs, with: &Ms2ex.SkillTab.changeset/2)
    |> cast_assoc(:stats, with: &Ms2ex.CharacterStats.changeset/2)
    |> cast_assoc(:wallet, with: &Ms2ex.Wallet.changeset/2)
    |> validate_required(@fields)
    |> unique_constraint(:name)
  end

  def job_id(%{awakened: true} = char), do: real_job_id(char) * 10 + 1

  def job_id(char), do: real_job_id(char) * 10

  def real_job_id(character) do
    Keyword.get(Job.__enum_map__(), character.job)
  end

  def max_level(), do: @max_level
end
