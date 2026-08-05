use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: do_response
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18000,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_resp_body = "body"
            ngx.ctx.t1k_context = "context"
            ngx.ctx.t1k_extra = buffer:new()
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x00\x00\x00\x00"
--- tcp_query eval
qr/\x41\x06\x00\x00\x00header\x11.*HTTP\/1.1 200 OK.*\x12\x04\x00\x00\x00body\x25\x07\x00\x00\x00context\x13\x12\x00\x00\x00\x1d.*\xa0\x08\x00\x00\x00Proto:3\x0a/s
--- no_error_log
[error]



=== TEST 2: do_response no body
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18000,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_context = "context"
            ngx.ctx.t1k_extra = buffer:new()
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x00\x00\x00\x00"
--- tcp_query eval
qr/\x41\x06\x00\x00\x00header\x11.*HTTP\/1.1 200 OK.*\x25\x07\x00\x00\x00context\x13\x12\x00\x00\x00\x1d.*\xa0\x08\x00\x00\x00Proto:3\x0a/s
--- no_error_log
[error]



=== TEST 3: do_response no context
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18000,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_resp_body = "body"
            ngx.ctx.t1k_extra = buffer:new()
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x00\x00\x00\x00"
--- tcp_query eval
qr/\x41\x06\x00\x00\x00header\x11.*HTTP\/1.1 200 OK.*\x12\x04\x00\x00\x00body\x13\x12\x00\x00\x00\x1d.*\xa0\x08\x00\x00\x00Proto:3\x0a/s
--- no_error_log
[error]



=== TEST 4: do_response no log_resp
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
lua-resty-t1k: skip response logging
--- log_level: debug



=== TEST 5: do_response no req_header
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
            }
            ngx.ctx.t1k_extra = "extra"
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
lua-resty-t1k: missing request header in context
--- log_level: warn



=== TEST 6: do_response no extra
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            ngx.ctx.t1k_opts = {
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
lua-resty-t1k: missing extra data in context
--- log_level: warn



=== TEST 7: do_response logs a connect failure
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18001,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_resp_body = "body"
            ngx.ctx.t1k_context = "context"
            ngx.ctx.t1k_extra = buffer:new()

            ngx.say("ok")
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- response_body
ok
--- error_log eval
qr/lua-resty-t1k: failed to report response after [\d.]+ ms: failed to get socket: failed to connect to t1k server 127\.0\.0\.1:18001/
--- wait: 0.2
--- log_level: error



=== TEST 8: do_response logs a receive failure
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18000,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_resp_body = "body"
            ngx.ctx.t1k_context = "context"
            ngx.ctx.t1k_extra = buffer:new()

            ngx.say("ok")
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41"
--- response_body
ok
--- error_log eval
qr/lua-resty-t1k: failed to report response after [\d.]+ ms: failed to receive info packet from t1k server 127\.0\.0\.1:18000/
--- log_level: error



=== TEST 9: do_response logs the elapsed time on success
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"

            ngx.ctx.t1k_opts = {
                host = "127.0.0.1",
                port = 18000,
                log_resp = true,
            }
            ngx.ctx.t1k_req_header = "header"
            ngx.ctx.t1k_resp_body = "body"
            ngx.ctx.t1k_context = "context"
            ngx.ctx.t1k_extra = buffer:new()

            ngx.say("ok")
        }

        log_by_lua_block {
            local response = require "resty.t1k.response"
            response.do_response()
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x00\x00\x00\x00"
--- response_body
ok
--- error_log eval
qr/lua-resty-t1k: reported response in [\d.]+ ms/
--- log_level: debug
