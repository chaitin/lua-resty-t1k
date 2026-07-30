use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 5 + 6);

run_tests();

__DATA__

=== TEST 1: do_socket
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local consts = require "resty.t1k.constants"
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result[consts.TAG_HEAD])
            ngx.say(result[consts.TAG_BODY])
            ngx.say(result[consts.TAG_EXTRA_BODY])
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- response_body
?
405
<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=false, tag=0x01, length=1
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=false, tag=0x02, length=3
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=true, tag=0x24, length=51
--- log_level: debug



=== TEST 2: do_socket with unix domain socket
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local consts = require "resty.t1k.constants"
            local socket = require "resty.t1k.socket"

            local t = {
                host = "unix:t1k.sock",
                uds = true,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result[consts.TAG_HEAD])
            ngx.say(result[consts.TAG_BODY])
            ngx.say(result[consts.TAG_EXTRA_BODY])
        }
    }
--- request
GET /t
--- tcp_listen: t1k.sock
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- response_body
?
405
<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server unix:t1k.sock
lua-resty-t1k: received packet from t1k server unix:t1k.sock: finished=false, tag=0x01, length=1
lua-resty-t1k: received packet from t1k server unix:t1k.sock: finished=false, tag=0x02, length=3
lua-resty-t1k: received packet from t1k server unix:t1k.sock: finished=true, tag=0x24, length=51
--- log_level: debug



=== TEST 3: do_socket premature
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(true, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result)
        }
    }
--- request
GET /t
--- response_body
nil
--- no_error_log
[error]
--- error_log
lua-resty-t1k: socket operation prematurely aborted
--- log_level: debug



=== TEST 4: do_socket connection failed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result)
        }
    }
--- request
GET /t
--- response_body
nil
--- error_log
failed to get socket: failed to connect to t1k server 127.0.0.1:18000



=== TEST 5: do_socket timeout
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 100,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result)
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply_delay: 200ms
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- response_body
nil
--- error_log
failed to receive info packet from t1k server 127.0.0.1:18000: timeout



=== TEST 6: do_socket ignore return value
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, true)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            ngx.say(result)
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- response_body
nil
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=false, tag=0x01, length=1
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=false, tag=0x02, length=3
lua-resty-t1k: received packet from t1k server 127.0.0.1:18000: finished=true, tag=0x24, length=51
--- log_level: debug




=== TEST 7: do_socket invalid payload
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = "invalid payload"

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            payload = {
                { tag = 0x01, data = "hello" },
                "invalid payload",
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            payload = {
                { tag = 0x01, data = "hello" },
                { tag = "invalid tag", data = { " ", "world", "!" } },
            }

            ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

            payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = 42 },
            }

            ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end

        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- error_log
invalid payload to send to t1k server: table expected, got string
invalid payload item at index 2: table expected, got string
invalid tag in payload item at index 2: number expected, got string
invalid data in payload item at index 2: string or table expected, got number



=== TEST 8: do_socket short packet
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- error_log
failed to receive info packet from t1k server 127.0.0.1:18000



=== TEST 9: do_socket invalid first packet
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x01\x01\x00\x00\x00?"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- error_log
first packet is not MASK_FIRST from t1k server 127.0.0.1:18000



=== TEST 10: do_socket invalid packet data
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local socket = require "resty.t1k.socket"

            local t = {
                host = "127.0.0.1",
                port = 18000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            local payload = {
                { tag = 0x01, data = "hello" },
                { tag = 0x02, data = { " ", "world", "!" } },
            }

            local ok, err, result = socket.do_socket(false, t, payload, false)
            if not ok then
                ngx.log(ngx.ERR, err)
            end
        }
    }
--- request
GET /t
--- tcp_listen: 18000
--- tcp_reply eval
"\x41\x01\x00\x00\x00"
--- tcp_query_len: 22
--- tcp_query eval
"\x41\x05\x00\x00\x00hello\x82\x07\x00\x00\x00 world!"
--- error_log
failed to receive data from t1k server 127.0.0.1:18000
