use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3 + 6);

run_tests();

__DATA__
=== TEST 1: do_request blocked
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 18000,
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
--- tcp_listen: 18000
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
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
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
                   port = 18000,
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
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x01\x00\x00\x00."
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
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
                   port = 18000,
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
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x01\x00\x00\x00."
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
               local request = require "resty.t1k.request"

               local t = {
                   mode = "monitor",
                   host = "127.0.0.1",
                   port = 18000,
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
--- tcp_listen: 18000
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- request
GET /t/shell.php
--- response_body_like
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
--- log_level: debug


=== TEST 5 do_request refuse connection
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 18000,
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
lua-resty-t1k: failed to connect to t1k server 127.0.0.1:18000
--- log_level: debug


=== TEST 6: do_request timeout
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 18000,
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
--- tcp_listen: 18000
--- tcp_reply_delay: 200ms
--- tcp_reply eval
"\x41\x01\x00\x00\x00?\x02\x03\x00\x00\x00405\xa4\x33\x00\x00\x00<!-- event_id: c0c039a7c348486eaffd9e2f9846b66b -->"
--- request
GET /t/shell.php
--- response_body
passed
--- error_log
lua-resty-t1k: failed to receive info packet from t1k server 127.0.0.1:18000: timeout
--- log_level: debug


=== TEST 7: do_request unknown action
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 18000,
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
--- tcp_listen: 18000
--- tcp_reply eval
"\xc1\x01\x00\x00\x00~"
--- request
GET /t
--- response_body
passed
--- error_log
lua-resty-t1k: unknown action from t1k server: ~
--- log_level: debug


=== TEST 8: do_request remote address
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
--- more_headers
X-Forwarded-For: 1.1.1.1, 2.2.2.2, 2001:db8:3333:4444:5555:6666:7777:18000, 3.3.3.3
X-Real-IP: 100.100.100.100
--- response_body
ngx.var.http_x_real_ip or ngx.var.remote_addr is 100.100.100.100
ngx.var.http_x_forwarded_for: 2 or ngx.var.remote_addr is 2.2.2.2
ngx.var.http_x_forwarded_for: -2 or ngx.var.remote_addr is 2001:db8:3333:4444:5555:6666:7777:18000
ngx.var.http_non_existent_header or ngx.var.remote_addr is 127.0.0.1
--- no_error_log
[error]


=== TEST 9: do_request http2
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local request = require "resty.t1k.request"

               local t = {
                   mode = "block",
                   host = "127.0.0.1",
                   port = 18000,
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
--- tcp_listen: 18000
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
lua-resty-t1k: successfully connected to t1k server 127.0.0.1:18000
--- log_level: debug
