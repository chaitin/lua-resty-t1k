local bit = require "bit"

local buffer = require "resty.t1k.buffer"
local consts = require "resty.t1k.constants"
local file = require "resty.t1k.file"
local log = require "resty.t1k.log"
local utils = require "resty.t1k.utils"
local uuid = require "resty.t1k.uuid"

local _M = {
    _VERSION = '1.0.0',
}

local bor = bit.bor
local byte = string.byte
local char = string.char
local sub = string.sub
local fmt = string.format

local ngx = ngx
local nlog = ngx.log
local ngx_var = ngx.var
local ngx_req = ngx.req

local warn_fmt = log.warn_fmt
local debug_fmt = log.debug_fmt

local KEY_EXTRA_UUID = "UUID"
local KEY_EXTRA_LOCAL_ADDR = "LocalAddr"
local KEY_EXTRA_LOCAL_PORT = "LocalPort"
local KEY_EXTRA_REMOTE_ADDR = "RemoteAddr"
local KEY_EXTRA_REMOTE_PORT = "RemotePort"
local KEY_EXTRA_SCHEME = "Scheme"
local KEY_EXTRA_SERVER_NAME = "ServerName"
local KEY_EXTRA_PROXY_NAME = "ProxyName"
local KEY_EXTRA_REQ_BEGIN_TIME = "ReqBeginTime"
local KEY_EXTRA_HAS_RSP_IF_OK = "HasRspIfOK"
local KEY_EXTRA_HAS_RSP_IF_BLOCK = "HasRspIfBlock"

local T1K_PROTO_VERSION = "Proto:2\n"

local TAG_HEAD_WITH_MASK_FIRST = bor(consts.TAG_HEAD, consts.MASK_FIRST)
local TAG_EXTRA_WITH_MASK_LAST = bor(consts.TAG_EXTRA, consts.MASK_LAST)

local function read_request_body(req_body_size_opt)
    local ok, err

    ngx_req.read_body()
    local req_body = ngx_req.get_body_data()
    if not req_body then
        local path = ngx_req.get_body_file()
        if not path then
            return true, nil, nil
        end

        ok, err, req_body = file.read(path)
        if not ok then
            err = fmt("failed to read temporary file %s: %s", path, err)
            return ok, err, nil
        end
    end

    local req_body_size = #req_body
    if req_body_size > req_body_size_opt then
        nlog(debug_fmt("request body is too long: %d bytes, cut to %d bytes", req_body_size, req_body_size_opt))
        req_body = sub(req_body, 1, req_body_size_opt)
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

local function build_extra_buf(remote_addr_var, remote_addr_idx)
    local err

    local src_ip = get_remote_addr(remote_addr_var, remote_addr_idx)
    if not src_ip then
        err = fmt("failed to get remote_addr, var: %s, idx %d", remote_addr_var, remote_addr_idx)
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

    local buf = buffer:new()
    buf:add_kv_lf(KEY_EXTRA_UUID, uuid.generate_v4())
    buf:add_kv_lf(KEY_EXTRA_REMOTE_ADDR, src_ip)
    buf:add_kv_lf(KEY_EXTRA_REMOTE_PORT, src_port)
    buf:add_kv_lf(KEY_EXTRA_LOCAL_ADDR, local_ip)
    buf:add_kv_lf(KEY_EXTRA_LOCAL_PORT, local_port)
    buf:add_kv_lf(KEY_EXTRA_SCHEME, ngx_var.scheme)
    buf:add_kv_lf(KEY_EXTRA_SERVER_NAME, ngx_var.server_name)
    buf:add_kv_lf(KEY_EXTRA_PROXY_NAME, ngx_var.hostname)
    buf:add_kv_lf(KEY_EXTRA_REQ_BEGIN_TIME, fmt("%.0f", ngx_req.start_time() * 1000000))
    buf:add_kv_lf(KEY_EXTRA_HAS_RSP_IF_OK, "n")
    buf:add_kv_lf(KEY_EXTRA_HAS_RSP_IF_BLOCK, "n")

    return true, nil, buf
end

local function build_header_buffer()
    local headers, err = ngx_req.get_headers(0, true)
    if err then
        err = fmt("failed to call ngx_req.get_headers: %s", err)
        return nil, err, nil
    end

    local buf = buffer:new()
    buf:add(fmt("%s %s HTTP/%.1f", ngx_req.get_method(), ngx_var.request_uri, ngx_req.http_version()))
    buf:add_crlf()

    for k, v in pairs(headers) do
        buf:add_kv_crlf(k, v)
    end
    buf:add_crlf()

    return true, nil, buf
end

local function build_payload_buffer(opts)
    local ok, err
    local body, extra, extra_buf
    local buf = buffer:new()

    local req_body_size = opts.req_body_size * 1024
    ok, err, body = read_request_body(req_body_size)
    if not ok then
        return ok, err, nil
    end

    if body ~= nil then
        buf:add(char(consts.TAG_BODY), utils.int_to_char_length(#body), body)
    end

    buf:add(char(consts.TAG_VERSION), utils.int_to_char_length(#T1K_PROTO_VERSION), T1K_PROTO_VERSION)

    ok, err, extra_buf = build_extra_buf(opts.remote_addr_var, opts.remote_addr_idx)
    if not ok then
        return ok, err, nil
    end
    extra = extra_buf:tostring()
    buf:add(char(TAG_EXTRA_WITH_MASK_LAST), utils.int_to_char_length(#extra), extra)

    return true, nil, buf
end

local function receive_data(s, srv)
    local t = {}
    local ft = true
    local finished

    repeat
        local err
        local tag, length, packet, rsp_body

        packet, err = s:receive(consts.T1K_HEADER_SIZE)
        if err then
            err = fmt("failed to receive info packet from t1k server %s: %s", srv, err)
            return nil, err, nil
        end
        if not packet then
            err = fmt("empty packet from t1k server %s", srv)
            return nil, err, nil
        end

        if ft then
            if not utils.is_mask_first(byte(packet, 1, 1)) then
                err = fmt("first packet is not MASK_FIRST from t1k server %s", srv)
                return nil, err, nil
            end
            ft = false
        end

        finished, tag, length = utils.packet_parser(packet)
        if length > 0 then
            rsp_body, err = s:receive(length)
            if not rsp_body or #rsp_body ~= length then
                err = fmt("failed to receive payload from t1k server %s: %s", srv, err)
                return nil, err, nil
            end
            t[tag] = rsp_body
        end

    until (finished)

    return true, nil, t
end

local function send_header_buf(sock, header_buf)
    local ok, err
    ok, err = sock:send({ char(TAG_HEAD_WITH_MASK_FIRST), utils.int_to_char_length(header_buf:len()) })
    if not ok then
        return ok, err
    end
    ok, err = sock:send(header_buf)
    if not ok then
        return ok, err
    end

    return true, nil
end

local function do_socket(opts, header_buf, payload_buf)
    local ok, err
    local t, sock
    local host, port = opts.host, opts.port

    sock, err = ngx.socket.tcp()
    if not sock then
        err = fmt("failed to create socket: %s", err)
        return nil, err, nil
    end

    local server = fmt("%s:%d", host, port)
    ok, err = sock:connect(host, port)
    if not ok then
        sock:close()
        err = fmt("failed to connect to t1k server %s: %s", server, err)
        return ok, err, nil
    end
    nlog(debug_fmt("successfully connected to t1k server %s", server))

    sock:settimeouts(opts.connect_timeout, opts.send_timeout, opts.read_timeout)

    ok, err = send_header_buf(sock, header_buf)
    if not ok then
        sock:close()
        err = fmt("failed to send header data to t1k server %s: %s", server, err)
        return ok, err, nil
    end

    ok, err = sock:send(payload_buf)
    if not ok then
        sock:close()
        err = fmt("failed to send payload data to t1k server %s: %s", server, err)
        return ok, err, nil
    end

    ok, err, t = receive_data(sock, server)
    if not ok then
        return ok, err, nil
    end

    ok, err = sock:setkeepalive(opts.keepalive_timeout, opts.keepalive)
    if not ok then
        nlog(warn_fmt("failed to set keepalive: %s", err))
        sock:close()
    end

    return true, nil, t
end

function _M.do_request(opts)
    local ok, err
    local header_buf, payload_buf, t

    ok, err, header_buf = build_header_buffer(opts)
    if not ok then
        return ok, err, nil
    end

    ok, err, payload_buf = build_payload_buffer(opts)
    if not payload_buf then
        return ok, err, nil
    end

    ok, err, t = do_socket(opts, header_buf, payload_buf)
    if not ok then
        return ok, err, nil
    end

    local result = {
        action = t[consts.TAG_HEAD],
        status = t[consts.TAG_BODY],
        extra_header = t[consts.TAG_EXTRA_HEADER],
        event_id = utils.get_event_id(t[consts.TAG_EXTRA_BODY]),
    }

    return true, nil, result
end

return _M
