local buffer = require "resty.t1k.buffer"
local consts = require "resty.t1k.constants"
local file = require "resty.t1k.file"
local log = require "resty.t1k.log"
local socket = require "resty.t1k.socket"
local utils = require "resty.t1k.utils"
local uuid = require "resty.t1k.uuid"

local _M = {
    _VERSION = '1.0.0',
}

local fmt = string.format
local sub = string.sub

local ngx = ngx
local ngx_var = ngx.var
local nlog = ngx.log

local debug_fmt = log.debug_fmt

local function read_request_body(opt_req_body_size)
    local ok, err
    local req_body, req_body_size

    local content_length = tonumber(ngx_var.http_content_length) or 0
    local transfer_encoding = ngx_var.http_transfer_encoding
    if content_length == 0 and not transfer_encoding then
        return true, nil, nil
    end

    ngx.req.read_body()
    req_body = ngx.req.get_body_data()
    if req_body then
        req_body_size = #req_body
        if req_body_size > opt_req_body_size then
            nlog(debug_fmt("request body is too long, total size: %d bytes, truncated size: %d bytes", req_body_size, opt_req_body_size))
            req_body = sub(req_body, 1, opt_req_body_size)
        end

        return true, nil, req_body
    end

    local path = ngx.req.get_body_file()
    if not path then
        return true, nil, nil
    end

    ok, err, req_body = file.read(path, opt_req_body_size)
    if not ok then
        err = fmt("failed to read temporary file %s: %s", path, err)
        return ok, err, nil
    end

    return true, nil, req_body
end

local function get_remote_addr(remote_addr_var, remote_addr_idx)
    local addr
    if remote_addr_var then
        addr = utils.get_indexed_element(ngx_var[remote_addr_var], remote_addr_idx)
    end
    return addr or ngx_var.remote_addr
end

local function build_header()
    local http_version = ngx.req.http_version()
    if not http_version or http_version < 2.0 then
        return true, nil, ngx.req.raw_header()
    end

    local headers, err = ngx.req.get_headers(0, true)
    if err then
        err = fmt("failed to call ngx.req.get_headers: %s", err)
        return nil, err, nil
    end

    local buf = buffer:new()
    buf:add(fmt("%s %s HTTP/%.1f\r\n", ngx.req.get_method(), ngx_var.request_uri, http_version))

    for k, v in pairs(headers) do
        buf:add(k, ": ", utils.parse_header_value(v), "\r\n")
    end
    buf:add("\r\n")

    return true, nil, buf
end

local function build_body(opts)
    local ok, err
    local body

    local req_body_size = opts.req_body_size * 1024
    ok, err, body = read_request_body(req_body_size)
    if not ok then
        return ok, err, nil
    end

    return true, nil, body
end

local function build_extra(opts)
    local err

    local src_ip = get_remote_addr(opts.remote_addr_var, opts.remote_addr_idx)
    if not src_ip then
        err = fmt("failed to get remote_addr, var: %s, idx %d", opts.remote_addr_var, opts.remote_addr_idx)
        return nil, err
    end

    local src_port = ngx_var.remote_port
    if not src_port then
        err = "failed to get ngx_var.remote_port"
        return nil, err, nil
    end

    local local_ip = ngx_var.server_addr
    if not local_ip then
        err = "failed to get ngx_var.server_addr"
        return nil, err, nil
    end

    local local_port = ngx_var.server_port
    if not local_port then
        err = "failed to get ngx_var.server_port"
        return nil, err, nil
    end

    local extra = buffer:new({
        consts.KEY_EXTRA_NEW_VER_FLAG, "\n",
        consts.KEY_EXTRA_REMOTE_PORT, src_port, "\n",
        consts.KEY_EXTRA_LOCAL_PORT, local_port, "\n",
        consts.KEY_EXTRA_REMOTE_ADDR, src_ip, "\n",
        consts.KEY_EXTRA_LOCAL_ADDR, local_ip, "\n",
        consts.KEY_EXTRA_SERVER_NAME, ngx_var.server_name, "\n",
        consts.KEY_EXTRA_SCHEME, ngx_var.scheme, "\n",
        consts.KEY_EXTRA_PROXY_NAME, ngx_var.hostname, "\n",
        consts.KEY_EXTRA_UUID, uuid.generate_v4(), "\n",
        consts.KEY_EXTRA_HAS_RSP_IF_OK, opts.log_resp and "y\n" or "n\n",
        consts.KEY_EXTRA_HAS_RSP_IF_BLOCK, "n\n",
        consts.KEY_EXTRA_REQ_BEGIN_TIME, fmt("%.0f\n", ngx.req.start_time() * 1000000),
    })

    if opts.log_resp then
        ngx.ctx.t1k_extra = extra
    end

    return true, nil, extra
end

function _M.do_request(opts)
    local ok, err
    local header, body, extra, t

    ok, err, header = build_header(opts)
    if not ok then
        return ok, err, nil
    end

    ok, err, body = build_body(opts)
    if not ok then
        return ok, err, nil
    end

    ok, err, extra = build_extra(opts)
    if not ok then
        return ok, err, nil
    end

    local payload = {
        { tag = consts.TAG_HEAD, data = header },
        { tag = consts.TAG_BODY, data = body },
        { tag = consts.TAG_EXTRA, data = extra },
        { tag = consts.TAG_VERSION, data = consts.T1K_PROTO },
    }

    ok, err, t = socket.do_socket(false, opts, payload, false)
    if not ok then
        return ok, err, nil
    end

    if opts.mode == consts.MODE_BLOCK then
        local extra_header = t[consts.TAG_EXTRA_HEADER]
        if extra_header then
            ngx.ctx.t1k_extra_header = extra_header
        end
    end

    if opts.log_resp then
        ngx.ctx.t1k_req_header = header

        local context = t[consts.TAG_CONTEXT]
        if context then
            ngx.ctx.t1k_context = context
        end

        if t[consts.TAG_HEAD] == consts.ACTION_BLOCKED then
            ngx.ctx.tx_skipped = true
        end
    end

    local result = {
        action = t[consts.TAG_HEAD],
        status = t[consts.TAG_BODY],
        event_id = utils.get_event_id(t[consts.TAG_EXTRA_BODY]),
    }

    return true, nil, result
end

return _M
