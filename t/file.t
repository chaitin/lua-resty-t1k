use Test::Nginx::Socket;

our $HttpConfig = <<'_EOC_';
    lua_package_path "lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
_EOC_

repeat_each(3);

plan tests => repeat_each() * (blocks() * 3);

run_tests();

__DATA__

=== TEST 1: read
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local file = require "resty.t1k.file"
                local path = ngx.var.document_root .. "/foo.bar"
                local ok, err, content = file.read(path)
                ngx.print(content)
            }
        }
--- user_files
>>> foo.bar
Hello, world!
--- request
GET /t
--- response_body
Hello, world!
--- no_error_log
[error]



=== TEST 2: read non-existent file
--- http_config eval: $::HttpConfig
--- config
        location /t {
            content_by_lua_block {
                local file = require "resty.t1k.file"
                local ok, err, content = file.read("/opt/non_existent_file")
                ngx.say("err: ", err)
            }
        }
--- request
GET /t
--- response_body
err: /opt/non_existent_file: No such file or directory
--- no_error_log
[error]
