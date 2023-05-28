use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "$pwd/lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
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
                ngx.say(b:tostring())
                ngx.say("b:len(): ", b:len())
            }
        }
--- request
GET /t
--- response_body
hello world!
b:len(): 12
--- no_error_log
[error]


=== TEST 2: buffer add_lf
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local buffer = require "resty.t1k.buffer"
                local b = buffer:new()
                b:add_lf()
                ngx.say(b:tostring() == "\x0a")
                ngx.say("b:len(): ", b:len())
            }
        }
--- request
GET /t
--- response_body
true
b:len(): 1
--- no_error_log
[error]


=== TEST 3: buffer add_lf
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local buffer = require "resty.t1k.buffer"
                local b = buffer:new()
                b:add_crlf()
                ngx.say(b:tostring() == "\x0d\x0a")
                ngx.say("b:len(): ", b:len())
            }
        }
--- request
GET /t
--- response_body
true
b:len(): 2
--- no_error_log
[error]


=== TEST 4: buffer add_kv_lf
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local buffer = require "resty.t1k.buffer"
                local b = buffer:new()
                b:add_kv_lf("k1", "v1")
                ngx.print(b:tostring())
                ngx.say("b:len(): ", b:len())
                b:add_kv_lf("k2", "v2")
                ngx.print(b:tostring())
                ngx.say("b:len(): ", b:len())
            }
        }
--- request
GET /t
--- response_body
k1:v1
b:len(): 6
k1:v1
k2:v2
b:len(): 12
--- no_error_log
[error]


=== TEST 5: buffer add_kv_crlf
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local buffer = require "resty.t1k.buffer"
                local b = buffer:new()
                b:add_kv_crlf("k1", "v1")
                ngx.print(b:tostring())
                ngx.say("b:len(): ", b:len())
                b:add_kv_crlf("k2", "v2")
                ngx.print(b:tostring())
                ngx.print("b:len(): ", b:len())
            }
        }
--- request
GET /t
--- response_body eval
"k1: v1\r\nb:len(): 8
k1: v1\r\nk2: v2\r\nb:len(): 16"
--- no_error_log
[error]
