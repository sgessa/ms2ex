defmodule Ms2ex.Items.Type do
  import EctoEnum

  defenum(Type,
    none: 0,
    currency: 1,
    furnishing: 2,
    pet: 3,
    lapenshard: 4,
    medal: 5,
    earring: 12,
    hat: 13,
    clothes: 14,
    pants: 15,
    gloves: 16,
    shoes: 17,
    cape: 18,
    necklace: 19,
    ring: 20,
    belt: 21,
    overall: 22,
    bludgeon: 30,
    dagger: 31,
    longsword: 32,
    scepter: 33,
    throwingStar: 34,
    spellbook: 40,
    shield: 41,
    greatsword: 50,
    bow: 51,
    staff: 52,
    cannon: 53,
    blade: 54,
    knuckle: 55,
    orb: 56
  )

  def value(name), do: Keyword.get(Type.__enum_map__(), name)

  def key(type_id) do
    Type.__enum_map__()
    |> Enum.find(fn {_k, v} -> v == type_id end)
    |> elem(0)
  end
end
