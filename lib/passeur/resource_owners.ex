defmodule Passeur.ResourceOwners do
  @behaviour Boruta.Oauth.ResourceOwners

  alias Boruta.Oauth.ResourceOwner

  @impl true
  def get_by(username: username) do
    admin_username = Application.get_env(:passeur, :admin_username)

    if username == admin_username do
      {:ok, %ResourceOwner{sub: "admin", username: admin_username}}
    else
      {:error, "User not found"}
    end
  end

  def get_by(sub: "admin", scope: _scope) do
    admin_username = Application.get_env(:passeur, :admin_username)
    {:ok, %ResourceOwner{sub: "admin", username: admin_username}}
  end

  def get_by(sub: _sub, scope: _scope) do
    {:error, "User not found"}
  end

  @impl true
  def check_password(%ResourceOwner{sub: "admin"}, password) do
    admin_password_hash = Application.get_env(:passeur, :admin_password_hash)

    if Argon2.verify_pass(password, admin_password_hash) do
      :ok
    else
      {:error, "Invalid password"}
    end
  end

  def check_password(_resource_owner, _password) do
    Argon2.no_user_verify()
    {:error, "Invalid credentials"}
  end

  @impl true
  def authorized_scopes(%ResourceOwner{sub: "admin"}) do
    [%Boruta.Oauth.Scope{name: "mcp:read", public: true}]
  end

  def authorized_scopes(_resource_owner) do
    []
  end

  @impl true
  def claims(%ResourceOwner{sub: sub, username: username}, _scope) do
    %{"sub" => sub, "username" => username}
  end
end
