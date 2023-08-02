use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: buffer add
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"
            local b = buffer:new()
            b:add("hello")
            b:add(" ", "world", "!")
            ngx.say(b[1], b[2], b[3], b[4])
            ngx.say(b:len())
        }
    }
--- request
GET /t
--- response_body
hello world!
12
--- no_error_log
[error]



=== TEST 2: buffer add_crlf
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"
            local b = buffer:new()
            b:add_crlf()
            b:add_crlf()
            ngx.print(b[1], b[2])
        }
    }
--- request
GET /t
--- response_body eval
"\r\n\r\n"
--- no_error_log
[error]



=== TEST 3: buffer add_kv_crlf
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua_block {
            local buffer = require "resty.t1k.buffer"
            local b = buffer:new()
            b:add_kv_crlf("k1", "v1")
            ngx.print(b[1], b[2], b[3], b[4])
            b:add_kv_crlf("k2", "v2")
            ngx.print(b[5], b[6], b[7], b[8])
        }
    }
--- request
GET /t
--- response_body eval
"k1: v1\r\nk2: v2\r\n"
--- no_error_log
[error]
