use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 4 + 1);

run_tests();

__DATA__

=== TEST 1: do_header_filter extra headers
--- http_config eval: $::HttpConfig
--- config
    location /t {
        access_by_lua_block {
            ngx.ctx.t1k_extra_header = "k1:v1\nk2:v2\nk3:v3\n"
        }

        header_filter_by_lua_block {
            local header = require "resty.t1k.header"
            header.do_header_filter()
        }

        content_by_lua_block {
            ngx.say("hi")
        }
    }
--- request
GET /t
--- response_headers
k1: v1
k2: v2
k3: v3
--- no_error_log
[error]



=== TEST 2: do_header_filter filter builtin content-type
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
            }
            ngx.header["Content-Type"] = "text/event-stream"
        }

        header_filter_by_lua_block {
            local header = require "resty.t1k.header"
            header.do_header_filter()
            ngx.header["TX-Passed"] = ngx.ctx.tx_skipped and "true" or "false"
        }
    }
--- request
GET /t
--- response_headers
Content-Type: text/event-stream
TX-Passed: true
--- no_error_log
[error]



=== TEST 3: do_header_filter filter extra content-type
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
                ignored_content_types = {
                    ["text/plain"] = true,
                },
            }
            ngx.header["Content-Type"] = "text/plain"
        }

        header_filter_by_lua_block {
            local header = require "resty.t1k.header"
            header.do_header_filter()
            ngx.header["TX-Passed"] = ngx.ctx.tx_skipped and "true" or "false"
        }
    }
--- request
GET /t
--- response_headers
Content-Type: text/plain
TX-Passed: true
--- no_error_log
[error]



=== TEST 4: do_header_filter no log_resp
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.say("hello world")
        }

        header_filter_by_lua_block {
            local header = require "resty.t1k.header"
            header.do_header_filter()
            ngx.header["TX-Passed"] = ngx.ctx.tx_skipped and "true" or "false"
        }
    }
--- request
GET /t
--- response_headers
TX-Passed: false
--- no_error_log
[error]
--- error_log
lua-resty-t1k: skip content type filtering
--- log_level: debug
