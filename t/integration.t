use Test::Nginx::Socket 'no_plan';

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
    lua_socket_log_errors off;
_EOC_

run_tests();

__DATA__
=== TEST 1: integration test blocked
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "block",
                   host = "detector.ip.addr",
                   port = 8000,
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
--- request
GET /t/shell.php
--- response_body_like eval
'^{"code": 403, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": ".*"}$'
--- error_code: 403
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server detector.ip.addr:8000
--- log_level: debug
--- skip_eval
4: not exists($ENV{INTEGRATION_TEST})


=== TEST 2: integration test blocked http2
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "block",
                   host = "detector.ip.addr",
                   port = 8000,
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
--- http2
--- request
GET /t/shell.php
--- response_body_like eval
'^{"code": 403, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": ".*"}$'
--- error_code: 403
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server detector.ip.addr:8000
--- log_level: debug
--- skip_eval
4: not exists($ENV{INTEGRATION_TEST})


=== TEST 3: integration test monitor
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "monitor",
                   host = "detector.ip.addr",
                   port = 8000,
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
--- request
GET /t/shell.php
--- response_body
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server detector.ip.addr:8000
--- log_level: debug
--- skip_eval
4: not exists($ENV{INTEGRATION_TEST})


=== TEST 4: integration test monitor http2
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "monitor",
                   host = "detector.ip.addr",
                   port = 8000,
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
--- http2
--- request
GET /t/shell.php
--- response_body
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: successfully connected to t1k server detector.ip.addr:8000
--- log_level: debug
--- skip_eval
4: not exists($ENV{INTEGRATION_TEST})


=== TEST 5: integration test disabled
--- http_config eval: $::HttpConfig
--- config
       location /t {
           access_by_lua_block {
               local t1k = require "resty.t1k"

               local t = {
                   mode = "off",
               }

               t1k.do_access(t)
           }

           content_by_lua_block {
               ngx.say("passed")
           }
       }
--- request
GET /t/shell.php
--- response_body
passed
--- no_error_log
[error]
--- error_log
lua-resty-t1k: t1k is not enabled
--- log_level: debug


=== TEST 6: integration test configuration priority
--- http_config eval: $::HttpConfig
--- config
        access_by_lua_block {
            local t1k = require "resty.t1k"

            local t = {
                mode = "block",
                host = "detector.ip.addr",
                port = 8000,
                connect_timeout = 1000,
                send_timeout = 1000,
                read_timeout = 1000,
                req_body_size = 1024,
                keepalive_size = 16,
                keepalive_timeout = 10000,
            }

            t1k.do_access(t)
        }

        location /pass {
            access_by_lua_block {
            }

            content_by_lua_block {
                ngx.say("passed")
            }
        }

        location /block {
            content_by_lua_block {
                ngx.say("there must be a problem when you see this line")
            }
        }
--- request eval
["GET /pass/shell.php", "GET /block/shell.php"]
--- response_body_like eval
["passed", '^{"code": 403, "success":false, "message": "blocked by Chaitin SafeLine Web Application Firewall", "event_id": ".*"}$']
--- error_code eval
[200, 403]
--- no_error_log
[error]
--- skip_eval
6: not exists($ENV{INTEGRATION_TEST})
