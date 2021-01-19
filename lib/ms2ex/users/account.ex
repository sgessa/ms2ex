defmodule Ms2ex.Users.Account do
  use Ecto.Schema

  import Ecto.Changeset

  schema "accounts" do
    has_many :characters, Ms2ex.Users.Character

    field :password, :string, virtual: true
    field :password_hash, :string
    field :username, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:username, :password])
    |> maybe_encrypt_password()
    |> validate_required([:username, :password_hash])
    |> unique_constraint(:username)
  end

  defp maybe_encrypt_password(account) do
    if pwd = get_change(account, :password) do
      change(account, password_hash: Bcrypt.hash_pwd_salt(pwd))
    else
      account
    end
  end
end
