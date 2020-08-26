# VerneMQ Container

## Load plugins
To load a plugin using an absolute path:
```
vmq-admin script load path="$VERNEMQ_PLUGIN_PATH/src/auth/auth.lua"
```

To execute from external terminal:
```
yarn genstack build --service=vernemq && docker exec -it proj_vernemq_1 bash -c "vmq-admin script reload path=/vernemq/share/lua/plugins//src/auth/auth.lua"
```

Examples:
https://www.gitmemory.com/issue/vernemq/vernemq/1173/491175441
https://github.com/vernemq/vernemq/blob/master/apps/vmq_diversity/test/postgres_test.lua
https://github.com/vernemq/vernemq/blob/93d7c404b99bbf080416ad79c1d54f652537ad60/apps/vmq_diversity/src/vmq_diversity_postgres.erl
https://github.com/vernemq/vernemq/issues/447
https://github.com/vernemq/docker-vernemq/issues/19
