import Config

config :passeur,
  port: 4000,
  admin_username: "admin",
  admin_password_hash: "$argon2id$v=19$m=65536,t=3,p=4$placeholder",
  secret_key_base: "dev_only_change_me_in_production_at_least_64_bytes_long_xxxxxxxxxxxxxxxxxxxxxxxxxx"

config :passeur, Passeur.Repo,
  username: "passeur",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  database: "passeur_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :passeur,
  server_url: "http://localhost:4000"

config :boruta, Boruta.Oauth,
  issuer: "http://localhost:4000"
