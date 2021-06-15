-- import default hooks and cache logic
-- require "auth/auth_commons"

-- import shared database query logic
require "auth/postgres_cockroach_commons"

-- import internal utilities
require "plugins/src/utilities/string"
require "plugins/src/utilities/logging"
require "plugins/src/utilities/postgres"

-- constants
MQTT_TOPIC_DELIMITER_PATTERN = "([^/]+)"
APP_PREFIX = os.getenv("APP_PREFIX") or "project"
MQTT_DATABASE_CHANNEL_PREFIX = os.getenv("MQTT_DATABASE_CHANNEL_PREFIX") or "pg"
DATABASE_ID_COLUMN_NAME = os.getenv("DATABASE_ID_COLUMN_NAME") or "id"
AUTH_AUTO_ADMIN_FALLBACK = (os.getenv("AUTH_AUTO_ADMIN_FALLBACK") or false) == "true"
MQTT_ADMIN_USERNAME = os.getenv("MQTT_ADMIN_USERNAME") or "admin"
MQTT_ADMIN_SECRET = os.getenv("MQTT_ADMIN_SECRET") or "password"

-- Hook to handle new client registrations.
-- The JWT token should be in the username field, this field supports a max length of 655535 bytes after encoding (UTF-8 encoded).
function auth_on_register(reg)
  log("The auth_on_register hook is triggered.")
  verbose("The following registration is requested:")
  verbose(reg)

  username = reg.username
  password = reg.password
  jwt = username

  -- guard: check if skipping the authentication is allowed
  if is_admin_login(username, password) == true then
    return true
  end

  jwt_is_valid = verify_jwt(jwt)

  -- guard: check if the JWT is valid
  if jwt_is_valid == false then
    verbose("Refusing client with invalid JWT credentials:")
    verbose(jwt)
    return false
  end

  -- true by default when guards are all passed
  verbose("Allowing client to connect with valid JWT credentials:")
  verbose(jwt)
  return true
end

-- Hook to handle the publish of new messages.
function auth_on_publish(pub)
  verbose("The auth_on_publish hook is triggered.")
  verbose("The following publish is requested:")
  verbose(pub)

  username = pub.username
  jwt = username
  topic = pub.topic
  qos = pub.qos
  parsed_pg_topic = parse_pg_topic(topic)

  -- guard: allow everything except PG related events by default
  if parsed_pg_topic.is_pg_event == false then
    verbose("Allowing the publish of an event as it is not PG related.")
    return true
  end

  -- guard: check if skipping the authentication is allowed
  if is_admin_request(username) then
    verbose("Allowing the publish of an event as the request has admin permissions.")
    return true
  end

  verbose("Refusing the publish of an event because of the lack of permissions.")
  return false
end

-- Hook to handle the subscription to new topics.
-- pg/update/identities/id/373465df-3ca9-4361-b5c1-2c446a0e1b80
-- pg/update/identities/id/0381f908-0f46-45b9-9c52-389182691ca6
-- ca6 = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAiaWRlbnRpdHlfaWQiOiAiMDM4MWY5MDgtMGY0Ni00NWI5LTljNTItMzg5MTgyNjkxY2E2IiB9.9IdcspKF6et762oHfVGe9mrAR23saSLQpe2_be7FrOE
function auth_on_subscribe(sub)
  log("The auth_on_subscribe hook is triggered.")
  verbose("The following subscription is requested:")
  verbose(sub)

  username = sub.username
  jwt = username

  -- guard: check if skipping the authentication is allowed
  if is_admin_request(username) then
    verbose("Allowing the subscription as the request has admin permissions.")
    return true
  end

  topic = sub.topics[1][1]
  qos = sub.topics[1][2]
  parsed_pg_topic = parse_pg_topic(topic)

  if parsed_pg_topic.is_pg_event then
    table_name = parsed_pg_topic.table_name
    column_name = parsed_pg_topic.column_name
    column_value = parsed_pg_topic.column_value

    switch_identity_query = "SELECT * FROM set_current_identity_by_jwt($1);"
    has_access_query = "SELECT ".. DATABASE_ID_COLUMN_NAME .." FROM ".. table_name .." WHERE ".. column_name .." = $1 LIMIT 1;"
    switch_identity_result = postgres.execute(identity_pool_id, switch_identity_query, jwt)
    has_access_result = postgres.execute(identity_pool_id, has_access_query, column_value)
    has_access = (#has_access_result == 1)

    verbose("Has access query:")
    verbose(query)
    verbose("Has access result:")
    verbose(has_access_result)

    if has_access == false then
      verbose("Access for subscription has been denied!")
      return false
    end
  end

  verbose("Access for subscription has been granted!")
  return true
end

-- Hook to handle the delivery of messages to the subscribed clients.
-- NOTE: rewrites are not working yet?
function on_deliver(message)
  verbose("The on_deliver hook is triggered.")
  verbose("The following message is being delivered:")
  verbose(message)

  return message
end

-- Hook to handle when a client closes connection or gets disconnected by a duplicate client.
function on_client_offline(client)
  verbose("The on_client_offline hook is triggered.")
  verbose("The following client went offline:")
  verbose(client)
end

-- Hook to handle when a client closes connection or gets disconnected by a duplicate client.
function on_client_gone(client)
  verbose("The on_client_gone hook is triggered.")
  verbose("The following client is gone:")
  verbose(client)
end

-- Split the topic on the default seperator '/'
function split_topic(topic)
  topic_tokens = split_string(topic, MQTT_TOPIC_DELIMITER_PATTERN)

  return topic_tokens
end

-- Check whether a topic is an postgres event
function is_pg_event(topic)
  topic_tokens = split_topic(topic)
  is_pg_event = (topic_tokens[1] == MQTT_DATABASE_CHANNEL_PREFIX)

  return is_pg_event
end

-- Check whether a topic is an postgres event
function parse_pg_topic(topic)
  topic_tokens = split_topic(topic)
  parsed_pg_topic = {
    is_pg_event = is_pg_event(topic),
    operation_name = topic_tokens[2],
    table_name = topic_tokens[3],
    column_name = topic_tokens[4],
    column_value = topic_tokens[5],
  }

  return parsed_pg_topic
end

-- Check whether a JWT is valid and can be properly decoded and signed with the secret.
function verify_jwt(jwt)
  jwt_is_valid = false

  verbose("Got a request to verify a JWT:")
  verbose(jwt)

  jwt_verify_query = "SELECT * FROM verify_jwt($1);"
  jwt_verify_result = postgres.execute(identity_pool_id, jwt_verify_query, jwt)
  jwt_is_valid = jwt_verify_result[1].valid

  -- debugging
  verbose("The JWT verify result is:")
  verbose(jwt_verify_result)

  return jwt_is_valid
end

-- Check whether a certain request should be elevated to admin permissions.
function is_admin_request(username)

  -- guard: check for admin fallback
  if has_admin_fallback(username) == true then
    return true
  end

  -- guard: check for admin user
  if username == MQTT_ADMIN_USERNAME then
    return true
  end

  return false
end

-- Check whether a certain request should be elevated to admin permissions.
function is_admin_login(username, password)

  -- guard: check for admin login
  if username == MQTT_ADMIN_USERNAME and password == MQTT_ADMIN_SECRET then
    return true
  end

  -- guard: check for admin fallback
  if has_admin_fallback(username) == true then
    return true
  end

  return false
end

-- Check for an admin fallback
function has_admin_fallback(username)

  -- guard: check for admin fallback
  if username == nil and AUTH_AUTO_ADMIN_FALLBACK == true then
    return true
  end

  return false
end

-- the hooks table specifies which hooks this plugin is implementing
hooks = {
  auth_on_register = auth_on_register,
  auth_on_publish = auth_on_publish,
  auth_on_subscribe = auth_on_subscribe,
  on_deliver = on_deliver,
  on_client_offline = on_client_offline,
  on_client_gone = on_client_gone,
}
