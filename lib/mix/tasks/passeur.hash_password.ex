defmodule Mix.Tasks.Passeur.HashPassword do
  @shortdoc "Generates an Argon2 hash for the admin password"
  @moduledoc """
  Generates an Argon2 password hash for use in configuration.

      $ mix passeur.hash_password

  The task will prompt for the password and output the hash
  to be used in your config.exs as :admin_password_hash.
  """

  use Mix.Task

  @impl true
  def run(_args) do
    password = Mix.shell().prompt("Enter password:") |> String.trim()
    hash = Argon2.hash_pwd_salt(password)

    Mix.shell().info("""

    Add this to your config.exs:

        config :passeur,
          admin_password_hash: "#{hash}"
    """)
  end
end
