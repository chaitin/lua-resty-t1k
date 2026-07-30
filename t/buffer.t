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
            local b = buffer:new({"Hello", " "})
            b:add("World")
            b:add("!", "!", "!")
            ngx.say(b:tostring())
            ngx.say(b:len())
        }
    }
--- request
GET /t
--- response_body
Hello World!!!
14
--- no_error_log
[error]
