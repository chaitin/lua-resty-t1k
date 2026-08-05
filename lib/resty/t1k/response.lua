local buffer = require "resty.t1k.buffer"
local consts = require "resty.t1k.constants"
local log = require "resty.t1k.log"
local socket = require "resty.t1k.socket"
local utils = require "resty.t1k.utils"

local _M = {
    _VERSION = '1.0.0'
}

local fmt = string.format

local ngx = ngx
local ngx_now = ngx.now
local ngx_timer = ngx.timer
local ngx_update_time = ngx.update_time
local nlog = ngx.log

local debug_fmt = log.debug_fmt
local err_fmt = log.err_fmt
local warn_fmt = log.warn_fmt

local function build_header()
    local headers, err = ngx.resp.get_headers(0, true)
    if err then
        err = fmt("failed to call ngx.resp.get_headers: %s", err)
        return nil, err, nil
    end

    local buf = buffer:new()
    buf:add(fmt("HTTP/1.1 %d %s\r\n", ngx.status, consts.HTTP_STATUS_TEXT[ngx.status] or "Unknown"))

    for k, v in pairs(headers) do
        buf:add(k, ": ", utils.parse_header_value(v), "\r\n")
    end
    buf:add("\r\n")

    return true, nil, buf
end

local function build_extra()
    local extra = ngx.ctx.t1k_extra
    if extra == nil then
        return nil
    end

    extra:add(consts.KEY_EXTRA_RESP_BEGIN_TIME, fmt("%.0f\n", ngx.ctx.t1k_resp_begin_time or ngx.now() * 1000000))

    return extra
end

-- ngx.timer.at discards whatever the callback returns, so a failure inside
-- do_socket would otherwise be invisible. Wrap it to log the error and to
-- measure how long the report took.
local function report(premature, opts, payload)
    ngx_update_time()
    local begin_time = ngx_now()

    local ok, err = socket.do_socket(premature, opts, payload, true)

    ngx_update_time()
    local elapsed = (ngx_now() - begin_time) * 1000

    if not ok then
        nlog(err_fmt("failed to report response after %.3f ms: %s", elapsed, err))
        return
    end

    nlog(debug_fmt("reported response in %.3f ms", elapsed))
end

function _M.do_response()
    local ok, err
    local req_header, resp_header, body, extra, context

    local opts = ngx.ctx.t1k_opts
    if opts == nil or not opts.log_resp or ngx.ctx.tx_skipped then
        nlog(debug_fmt("skip response logging"))
        return
    end

    req_header = ngx.ctx.t1k_req_header
    if req_header == nil then
        nlog(warn_fmt("missing request header in context"))
        return
    end

    ok, err, resp_header = build_header()
    if not ok then
        nlog(warn_fmt("failed to build response header: %s", err))
        return
    end

    body = ngx.ctx.t1k_resp_body
    context = ngx.ctx.t1k_context

    extra = build_extra()
    if extra == nil then
        nlog(warn_fmt("missing extra data in context"))
        return
    end

    local payload = {
        { tag = consts.TAG_HEAD, data = req_header },
        { tag = consts.TAG_RSP_HEAD, data = resp_header },
        { tag = consts.TAG_RSP_BODY, data = body },
        { tag = consts.TAG_CONTEXT, data = context },
        { tag = consts.TAG_RSP_EXTRA, data = extra },
        { tag = consts.TAG_VERSION, data = consts.T1K_PROTO },
    }

    ok, err = ngx_timer.at(0, report, opts, payload)
    if not ok then
        nlog(err_fmt("failed to create timer to do response: %s", err))
        return
    end
end

return _M
