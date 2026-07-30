local body = require "resty.t1k.body"
local consts = require "resty.t1k.constants"
local header = require "resty.t1k.header"
local handler = require "resty.t1k.handler"
local log = require "resty.t1k.log"
local request = require "resty.t1k.request"
local response = require "resty.t1k.response"
local utils = require "resty.t1k.utils"

local lower = string.lower

local ngx = ngx
local nlog = ngx.log

local debug_fmt = log.debug_fmt
local log_fmt = log.fmt
local warn_fmt = log.warn_fmt

local _M = {
    _VERSION = '1.0.0'
}

local DEFAULT_T1K_CONNECT_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_SEND_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_READ_TIMEOUT = 1000 -- 1s
local DEFAULT_T1K_REQ_BODY_SIZE = 1024 -- 1024 KB
local DEFAULT_T1K_KEEPALIVE_SIZE = 256
local DEFAULT_T1K_KEEPALIVE_TIMEOUT = 60 * 1000 -- 60s
local DEFAULT_T1K_LOG_RESP = false
local DEFAULT_T1K_RESP_BODY_SIZE = 4 -- 4 KB

function _M.do_access(t, handle)
    local ok, err, result
    local opts = {}
    t = t or {}

    if not t.mode then
        return true, nil, nil
    end

    opts.mode = lower(t.mode)
    if opts.mode == consts.MODE_OFF then
        nlog(debug_fmt("t1k is not enabled"))
        return true, nil, nil
    end

    if opts.mode ~= consts.MODE_OFF and opts.mode ~= consts.MODE_BLOCK and opts.mode ~= consts.MODE_MONITOR then
        err = log_fmt("invalid t1k mode: %s", t.mode)
        return nil, err, nil
    end

    if not t.host then
        err = log_fmt("invalid t1k host: %s", t.host)
        return nil, err, nil
    end
    opts.host = t.host

    if utils.starts_with(opts.host, consts.UNIX_SOCK_PREFIX) then
        opts.uds = true
    else
        if not tonumber(t.port) then
            err = log_fmt("invalid t1k port: %s", t.port)
            return nil, err, nil
        end
        opts.port = tonumber(t.port)
    end

    opts.connect_timeout = t.connect_timeout or DEFAULT_T1K_CONNECT_TIMEOUT
    opts.send_timeout = t.send_timeout or DEFAULT_T1K_SEND_TIMEOUT
    opts.read_timeout = t.read_timeout or DEFAULT_T1K_READ_TIMEOUT
    opts.req_body_size = t.req_body_size or DEFAULT_T1K_REQ_BODY_SIZE
    opts.keepalive_size = t.keepalive_size or DEFAULT_T1K_KEEPALIVE_SIZE
    opts.keepalive_timeout = t.keepalive_timeout or DEFAULT_T1K_KEEPALIVE_TIMEOUT
    opts.log_resp = t.log_resp or DEFAULT_T1K_LOG_RESP

    if t.remote_addr then
        local var, idx = utils.to_var_idx(t.remote_addr)
        opts.remote_addr_var = var
        opts.remote_addr_idx = idx
    end

    if opts.log_resp then
        if t.resp_body_size and (not tonumber(t.resp_body_size)) then
            err = log_fmt("invalid t1k response body logging size: %s", t.resp_body_size)
            return nil, err, nil
        end
        opts.resp_body_size = t.resp_body_size and tonumber(t.resp_body_size) or DEFAULT_T1K_RESP_BODY_SIZE
        if opts.resp_body_size < 0 then
            err = log_fmt("t1k response body logging size cannot be negative: %d", opts.resp_body_size)
            return nil, err, nil
        end
        if opts.resp_body_size > 1024 then
            nlog(warn_fmt("t1k response body logging size is too large: %d KB, use with caution", opts.resp_body_size))
        end
        opts.ignored_content_types = utils.get_ignored_content_types(t.extra_ignored_content_types)

        ngx.ctx.t1k_opts = opts
    end

    ok, err, result = request.do_request(opts)
    if not ok then
        err = log_fmt("failed to detect the request: %s", err)
        return ok, err, nil
    end

    if handle and opts.mode == consts.MODE_BLOCK then
        ok, err = _M.do_handle(result)
        if not ok then
            err = log_fmt("failed to handle the result: %s", err)
            return ok, err, nil
        end
    end

    return ok, err, result
end

function _M.do_handle(r)
    return handler.handle(r)
end

function _M.do_header_filter()
    header.do_header_filter()
end

function _M.do_body_filter()
    body.do_body_filter()
end

function _M.do_log()
    response.do_response()
end

return _M
