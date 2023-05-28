use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "$pwd/lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3 + 7);

run_tests();

__DATA__
=== TEST 1: do_request block
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8880,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8880
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- request
GET /t/shell.php
--- response_body
{"code": 405, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": "c0c039a7c348486eaffd9e2f9846b66b"}
--- error_code eval
"405"
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:8880
--- log_level: debug


=== TEST 2: do_request passed
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8881,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8881
--- tcp_reply eval
"\x41\x01\x00\x00\x00.\xa1\x02\x00\x00\x00{}"
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:8881
--- log_level: debug


=== TEST 3: do_request trim request body
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8882,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 0.0625,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8882
--- tcp_reply eval
"\x41\x01\x00\x00\x00.\xa1\x02\x00\x00\x00{}"
--- request
GET /t
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
--- response_body_like
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: request body is too long: 123 bytes, cut to 64 bytes
--- log_level: debug


=== TEST 4: do_access monitor
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "monitor",
                   host = "127.0.0.1",
                   port = 8883,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               t1k.do_access(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8883
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- request
GET /t/shell.php
--- response_body_like
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:8883
--- log_level: debug


=== TEST 5: do_access bypass
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "off",
                   host = "127.0.0.1",
                   port = 8884,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               t1k.do_access(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8884
--- tcp_reply eval
"\x41\x01\x00\x00\x00.\xa1\x02\x00\x00\x00{}"
--- request
GET /t/shell.php
--- response_body_like
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: t1k is not enabled
--- log_level: debug


=== TEST 6: do_access invalid host
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "block"
               }

               t1k.do_access(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- request
GET /t
--- response_body_like
passed
--- error_log
lua-resty-t1k: invalid t1k host: nil
--- log_level: debug


=== TEST 7: do_access invalid port
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "block",
                   host = "127.0.0.1"
               }

               t1k.do_access(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- request
GET /t
--- response_body_like
passed
--- error_log
lua-resty-t1k: invalid t1k port: nil
--- log_level: debug


=== TEST 8: do_request refuse connection
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8885,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 0.0625,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- request
GET /t
--- response_body_like
passed
--- error_log
lua-resty-t1k: failed to connect to t1k server 127.0.0.1:8885
--- log_level: debug


=== TEST 9: do_request timeout
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8886,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 100,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }


           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8886
--- tcp_reply_delay: 200ms
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- request
GET /t/shell.php
--- response_body
passed
--- error_log
lua-resty-t1k: failed to receive info packet from t1k server 127.0.0.1:8886: timeout
--- log_level: debug


=== TEST 10: do_request unknown action
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8887,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 0.0625,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8887
--- tcp_reply eval
"\x41\x01\x00\x00\x00~\xa1\x02\x00\x00\x00{}"
--- request
GET /t
--- response_body
passed
--- error_log
lua-resty-t1k: unknown action from t1k server: ~
--- log_level: debug


=== TEST 11: do_request remote address
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local utils = require "resty.t1k.utils"
               ngx.say("ngx.var.http_x_real_ip or ngx.var.remote_addr is ", utils.get_indexed_element(ngx.var.http_x_real_ip) or ngx.var.remote_addr)
               ngx.say("ngx.var.http_x_forwarded_for: 2 or ngx.var.remote_addr is ", utils.get_indexed_element(ngx.var.http_x_forwarded_for, 2) or ngx.var.remote_addr)
               ngx.say("ngx.var.http_x_forwarded_for: -2 or ngx.var.remote_addr is ", utils.get_indexed_element(ngx.var.http_x_forwarded_for, -2) or ngx.var.remote_addr)
               ngx.say("ngx.var.http_non_existent_header or ngx.var.remote_addr is ", utils.get_indexed_element(ngx.var.http_non_existent_header) or ngx.var.remote_addr)
           }
       }
--- request
GET /t
--- request
GET /t
--- more_headers
X-Forwarded-For: 1.1.1.1, 2.2.2.2, 2001:db8:3333:4444:5555:6666:7777:8880, 3.3.3.3
X-Real-IP: 100.100.100.100
--- response_body
ngx.var.http_x_real_ip or ngx.var.remote_addr is 100.100.100.100
ngx.var.http_x_forwarded_for: 2 or ngx.var.remote_addr is 2.2.2.2
ngx.var.http_x_forwarded_for: -2 or ngx.var.remote_addr is 2001:db8:3333:4444:5555:6666:7777:8880
ngx.var.http_non_existent_header or ngx.var.remote_addr is 127.0.0.1
--- no_error_log
[error]


=== TEST 12: do_request http2
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 8888,
                   connect_timeout = 1000,
                   send_timeout = 1000,
                   read_timeout = 1000,
                   req_body_size = 1024,
                   keepalive_size = 16,
                   keepalive_timeout = 10000,
               }

               request.do_request(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- tcp_listen: 8888
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- http2
--- request
GET /t/shell.php
--- tcp_query eval
qr/.*HTTP\/2.0.*/
--- response_body
{"code": 405, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": "c0c039a7c348486eaffd9e2f9846b66b"}
--- error_code eval
"405"
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:8888
--- log_level: debug
