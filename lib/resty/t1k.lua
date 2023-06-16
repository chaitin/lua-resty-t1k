local consts = require "resty.t1k.constants"
local filter = require "resty.t1k.filter"
local handler = require "resty.t1k.handler"
local log = require "resty.t1k.log"
local request = require "resty.t1k.request"
local utils = require "resty.t1k.utils"

local lower = string.lower

local ngx = ngx
local nlog = ngx.log

local log_fmt = log.fmt
local debug_fmt = log.debug_fmt

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
    local ok, err, result
    opts = opts or {}

    if not opts.mode then
        return true, nil, nil
    end

    opts.mode = lower(opts.mode)
    if opts.mode == consts.MODE_OFF then
        nlog(debug_fmt("t1k is not enabled"))
        return true, nil, nil
    end

    if opts.mode ~= consts.MODE_OFF and opts.mode ~= consts.MODE_BLOCK and opts.mode ~= consts.MODE_MONITOR then
        err = log_fmt("invalid t1k mode: %s", opts.mode)
        return nil, err, nil
    end

    if not opts.host then
        err = log_fmt("invalid t1k host: %s", opts.host)
        return nil, err, nil
    end

    if not tonumber(opts.port) then
        err = log_fmt("invalid t1k port: %s", opts.port)
        return nil, err, nil
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

    ok, err, result = request.do_request(opts)
    return ok, err, result
end

function _M.do_handle(t)
    local ok, err = handler.handle(t)
    return ok, err
end

function _M.do_header_filter()
    filter.do_header_filter()
end

return _M
