-- unique ID for the default pool
identity_pool_id = "identity"

-- the default configuration to connect to the default pool with
local default_config = {
  pool_id = identity_pool_id,
  user = os.getenv("APP_PREFIX") .. "_" .. os.getenv("POSTGRES_IDENTITY_ROLE_NAME"),
  password = os.getenv("POSTGRES_IDENTITY_SECRET"),
  host = os.getenv("POSTGRES_HOST_NAME"),
  port = tonumber(os.getenv("POSTGRES_PORT")),
  database = os.getenv("POSTGRES_DATABASE_NAME"),
}

-- instantiate the pool for the default configuration
postgres.ensure_pool(default_config)