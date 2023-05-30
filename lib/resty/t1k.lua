local consts = require "resty.t1k.constants"
local filter = require "resty.t1k.filter"
local log = require "resty.t1k.log"
local request = require "resty.t1k.request"
local utils = require "resty.t1k.utils"

local ngx = ngx
local nlog = ngx.log

local debug_fmt = log.debug_fmt
local err_fmt = log.err_fmt

local _M = {
    _VERSION = '1.0.0'
}

local DEFAULT_T1K_CONNECT_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_SEND_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_READ_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_REQ_BODY_SIZE = 1024 -- 1024 KB
local DEFAULT_T1K_KEEPALIVE_SIZE = 256
local DEFAULT_T1K_KEEPALIVE_TIMEOUT = 60 * 1000 -- 60s

function _M.do_access(opts)
    opts = opts or {}

    if not opts.mode or (opts.mode ~= consts.T1K_MODE_BLOCK and opts.mode ~= consts.T1K_MODE_MONITOR) then
        nlog(debug_fmt("t1k is not enabled"))
        return
    end

    if not opts.host then
        nlog(err_fmt("invalid t1k host: %s", opts.host))
        return
    end

    if not tonumber(opts.port) then
        nlog(err_fmt("invalid t1k port: %s", opts.port))
        return
    end

    opts.connect_timeout = opts.connect_timeout or DEFAULT_T1K_CONNECT_TIMEOUT
    opts.send_timeout = opts.send_timeout or DEFAULT_T1K_SEND_TIMEOUT
    opts.read_timeout = opts.read_timeout or DEFAULT_T1K_READ_TIMEOUT
    opts.req_body_size = opts.req_body_size or DEFAULT_T1K_REQ_BODY_SIZE
    opts.keepalive_size = opts.keepalive_size or DEFAULT_T1K_KEEPALIVE_SIZE
    opts.keepalive_timeout = opts.keepalive_timeout or DEFAULT_T1K_KEEPALIVE_TIMEOUT

    if opts.remote_addr then
        local var, idx = utils.to_var_idx(opts.remote_addr)
        opts.remote_addr_var = var
        opts.remote_addr_idx = idx
    end

    request.do_request(opts)
end

function _M.do_header_filter()
    filter.do_header_filter()
end

return _M
