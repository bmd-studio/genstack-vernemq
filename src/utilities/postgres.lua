-- unique ID for the default pool
identity_pool_id = "identity"

-- the default configuration to connect to the default pool with
local default_config = {
  pool_id = identity_pool_id,
  user = (os.getenv("APP_PREFIX") or "project") .. "_" .. (os.getenv("POSTGRES_IDENTITY_ROLE_NAME") or "identity"),
  password = os.getenv("POSTGRES_IDENTITY_SECRET") or "password",
  host = os.getenv("POSTGRES_HOST_NAME") or "postgresql",
  port = tonumber(os.getenv("POSTGRES_PORT") or "5432"),
  database = os.getenv("POSTGRES_DATABASE_NAME") or "project",
}

-- instantiate the pool for the default configuration
postgres.ensure_pool(default_config)
