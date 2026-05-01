import Config

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "DATABASE_URL is not set"

  config :passeur, Passeur.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  port = String.to_integer(System.get_env("PORT") || "4000")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise "SECRET_KEY_BASE is not set"

  admin_username =
    System.get_env("ADMIN_USERNAME") ||
      raise "ADMIN_USERNAME is not set"

  admin_password_hash =
    System.get_env("ADMIN_PASSWORD_HASH") ||
      raise "ADMIN_PASSWORD_HASH is not set"

  server_url =
    System.get_env("SERVER_URL") ||
      raise "SERVER_URL is not set (e.g. https://mcp.example.com)"

  server_url = String.trim_trailing(server_url, "/")

  parsed = URI.parse(server_url)

  if parsed.path not in [nil, "", "/"] do
    raise "SERVER_URL must not contain a path (got #{inspect(server_url)}). Use the root URL only, e.g. https://mcp.example.com"
  end

  static_bearer_tokens =
    case System.get_env("PASSEUR_STATIC_BEARER_TOKENS") do
      nil -> []
      "" -> []
      raw -> raw |> String.split(",", trim: true) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    end

  config :passeur,
    port: port,
    admin_username: admin_username,
    admin_password_hash: admin_password_hash,
    secret_key_base: secret_key_base,
    server_url: server_url,
    static_bearer_tokens: static_bearer_tokens

  config :boruta, Boruta.Oauth,
    issuer: server_url
end
