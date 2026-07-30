package = "lua-resty-t1k-main"
version = "0-0"
source = {
    url = "git://github.com/chaitin/lua-resty-t1k",
    branch = "main",
}

description = {
    summary = "Lua implementation of the T1K protocol for Chaitin SafeLine Web Application Firewall",
    detailed = [[
      Check https://waf-ce.chaitin.cn/ for more information about Chaitin SafeLine Web Application Firewall.
    ]],
    homepage = "https://github.com/chaitin/lua-resty-t1k",
    license = "Apache License 2.0",
    maintainer = "Xudong Wang <xudong.wang@chaitin.com>"
}

build = {
   type = "builtin",
   modules = {
    ["resty.t1k"] = "lib/resty/t1k.lua",
    ["resty.t1k.body"] = "lib/resty/t1k/body.lua",
    ["resty.t1k.buffer"] = "lib/resty/t1k/buffer.lua",
    ["resty.t1k.constants"] = "lib/resty/t1k/constants.lua",
    ["resty.t1k.file"] = "lib/resty/t1k/file.lua",
    ["resty.t1k.handler"] = "lib/resty/t1k/handler.lua",
    ["resty.t1k.header"] = "lib/resty/t1k/header.lua",
    ["resty.t1k.log"] = "lib/resty/t1k/log.lua",
    ["resty.t1k.request"] = "lib/resty/t1k/request.lua",
    ["resty.t1k.response"] = "lib/resty/t1k/response.lua",
    ["resty.t1k.socket"] = "lib/resty/t1k/socket.lua",
    ["resty.t1k.utils"] = "lib/resty/t1k/utils.lua",
    ["resty.t1k.uuid"] = "lib/resty/t1k/uuid.lua",
   },
}
