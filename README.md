# lua-resty-t1k

## Name

Lua implementation of the T1K protocol for [Chaitin/SafeLine](https://github.com/chaitin/safeline) Web Application Firewall.

## Status

Production ready.

[![Test](https://github.com/chaitin/lua-resty-t1k/actions/workflows/test.yml/badge.svg)](https://github.com/chaitin/lua-resty-t1k/actions)

## Synopsis

```lua
 location / {
     access_by_lua_block {
         local t1k = require "resty.t1k"

         t1k.do_access {
             mode = "block",                            -- block or monitor or off, default off
             host = "foo.bar",                          -- required, SafeLine WAF detection service host
             port = 8000,                               -- required, SafeLine WAF detection service port
             connect_timeout = 1000,                    -- connect timeout, in milliseconds, integer, default 1s (1000ms)
             send_timeout = 1000,                       -- send timeout, in milliseconds, integer, default 1s (1000ms)
             read_timeout = 1000,                       -- read timeout, in milliseconds, integer, default 1s (1000ms)
             req_body_size = 1024,                      -- request body size, in KB, integer, default 1MB (1024KB)
             keepalive_size = 256,                      -- maximum concurrent idle connections to the SafeLine WAF detection service, integer, default 256
             keepalive_timeout = 60000,                 -- idle connection timeout, in milliseconds, integer, default 60s (60000ms)
             remote_addr = "http_x_forwarded_for: 1",   -- remote address from ngx.var.VARIABLE, string, default from ngx.var.remote_addr. Do not specify this option unless you know what are doing.
         }
     }

     header_filter_by_lua_block {
        local t1k = require "resty.t1k"
        t1k.do_header_filter()
     }
 }
```
