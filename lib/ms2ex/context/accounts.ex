defmodule Ms2ex.Context.Accounts do
  alias Ms2ex.{Repo, Schema}

  def authenticate(username, password) do
    account = Repo.get_by(Schema.Account, username: username)

    case account do
      nil -> {:error, :invalid_credentials}
      _ -> check_password(account, password)
    end
  end

  defp check_password(%Schema.Account{password_hash: hash} = account, pwd) do
    case Bcrypt.verify_pass(pwd, hash) do
      true -> {:ok, account}
      false -> {:error, :invalid_credentials}
    end
  end

  def get(id), do: Repo.get(Schema.Account, id)

  def create(attrs) do
    attrs = Schema.Account.set_default_assocs(attrs)

    %Schema.Account{}
    |> Schema.Account.changeset(attrs)
    |> Repo.insert()
  end

  def update(%Schema.Account{} = account, attrs) do
    account
    |> Schema.Account.changeset(attrs)
    |> Repo.update()
  end

  def delete(%Schema.Account{} = account), do: Repo.delete(account)
end
