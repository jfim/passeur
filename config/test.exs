import Config

config :passeur,
  port: 4002,
  admin_username: "admin",
  # password: "test_password"
  admin_password_hash:
    "$argon2id$v=19$m=65536,t=3,p=4$Qzopj5v+9pDO7dAGAutKbg$nzeaGYLv5FhmHU3JDaHRu7Fqu8ktbrHsdf4q7yKa1Hs",
  secret_key_base: "test_only_secret_key_base_at_least_64_bytes_long_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"

config :passeur, Passeur.Repo,
  username: "passeur",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  database: "passeur_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :passeur,
  server_url: "http://localhost:4002"

config :boruta, Boruta.Oauth, issuer: "http://localhost:4002"
