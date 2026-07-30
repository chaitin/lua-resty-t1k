use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3 + 4);

run_tests();

__DATA__

=== TEST 1: do_body_filter
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
                resp_body_size = 1024,
            }
            ngx.say("hello world")
        }

        body_filter_by_lua_block {
            local body = require "resty.t1k.body"
            body.do_body_filter()

            if not ngx.arg[2] then
                ngx.arg[1] = nil
                return
            end

            local resp_body = ngx.ctx.t1k_resp_body
            ngx.arg[1] = resp_body and string.upper(resp_body:tostring()) or "nil"
        }
    }
--- request
GET /t
--- response_body
HELLO WORLD
--- no_error_log
[error]
--- log_level: debug



=== TEST 2: do_body_filter truncate
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
                resp_body_size = 0.125,
            }
            ngx.say("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
        }

        body_filter_by_lua_block {
            local body = require "resty.t1k.body"
            body.do_body_filter()

            if not ngx.arg[2] then
                ngx.arg[1] = nil
                return
            end

            local resp_body = ngx.ctx.t1k_resp_body
            ngx.arg[1] = resp_body and resp_body:tostring() or "nil"
        }
    }
--- request
GET /t
--- response_body chomp
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut e
--- no_error_log
[error]
--- error_log
lua-resty-t1k: response body received completely, total size: 232 bytes, truncated size: 128 bytes
--- log_level: debug



=== TEST 3: do_body_filter no log_resp
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                resp_body_size = 1024,
            }
            ngx.say("hello world")
        }

        body_filter_by_lua_block {
            local body = require "resty.t1k.body"
            body.do_body_filter()

            if not ngx.arg[2] then
                ngx.arg[1] = nil
                return
            end

            local resp_body = ngx.ctx.t1k_resp_body
            ngx.arg[1] = resp_body and resp_body:tostring() or "nil"
        }
    }
--- request
GET /t
--- response_body chomp
nil
--- no_error_log
[error]
--- error_log
lua-resty-t1k: skip response body buffering
--- log_level: debug



=== TEST 4: do_body_filter tx passed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
                resp_body_size = 1024,
            }
            ngx.ctx.tx_skipped = true
            ngx.say("hello world")
        }

        body_filter_by_lua_block {
            local body = require "resty.t1k.body"
            body.do_body_filter()

            if not ngx.arg[2] then
                ngx.arg[1] = nil
                return
            end

            local resp_body = ngx.ctx.t1k_resp_body
            ngx.arg[1] = resp_body and resp_body:tostring() or "nil"
        }
    }
--- request
GET /t
--- response_body chomp
nil
--- no_error_log
[error]
--- error_log
lua-resty-t1k: skip response body buffering
--- log_level: debug



=== TEST 5: do_body_filter zero resp_body_size
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
            }
            ngx.say("hello world")
        }

        body_filter_by_lua_block {
            local body = require "resty.t1k.body"
            body.do_body_filter()

            if not ngx.arg[2] then
                ngx.arg[1] = nil
                return
            end

            local resp_body = ngx.ctx.t1k_resp_body
            ngx.arg[1] = resp_body and resp_body:tostring() or "nil"
        }
    }
--- request
GET /t
--- response_body chomp
nil
--- no_error_log
[error]
--- error_log
lua-resty-t1k: skip response body buffering for non-positive limit: 0
--- log_level: debug
