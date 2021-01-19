defmodule Ms2ex.Users do
  alias Ms2ex.Users.{Account, Character}
  alias Ms2ex.InventoryItems.Item
  alias Ms2ex.Repo

  import Ecto.Query, except: [update: 2]

  def authenticate(username, password) do
    account = Repo.get_by(Account, username: username)

    case account do
      nil -> {:error, :invalid_credentials}
      _ -> check_password(account, password)
    end
  end

  defp check_password(%Account{password_hash: hash} = account, pwd) do
    case Bcrypt.verify_pass(pwd, hash) do
      true -> {:ok, account}
      false -> {:error, :invalid_credentials}
    end
  end

  def get(id), do: Repo.get(Account, id)

  def create(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Account{} = account), do: Repo.delete(account)

  # Characters

  def create_character(%Account{} = account, attrs) do
    account
    |> Ecto.build_assoc(:characters)
    |> Character.changeset(attrs)
    |> Repo.insert()
  end

  def get_character(id), do: Repo.get(Character, id)

  def load_characters(%Account{} = account) do
    equips = where(Item, [i], i.slot_type != :none)
    Repo.preload(account, characters: [equips: equips])
  end
end
