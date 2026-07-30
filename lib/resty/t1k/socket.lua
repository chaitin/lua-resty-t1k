local bit = require "bit"

local consts = require "resty.t1k.constants"
local log = require "resty.t1k.log"
local utils = require "resty.t1k.utils"

local _M = {
    _VERSION = '1.0.0',
}

local bor = bit.bor
local byte = string.byte
local char = string.char
local fmt = string.format

local ngx = ngx
local ngx_socket = ngx.socket
local nlog = ngx.log

local debug_fmt = log.debug_fmt
local warn_fmt = log.warn_fmt

local function get_socket(opts, server)
    local ok, err
    local count, sock

    sock, err = ngx_socket.tcp()
    if not sock then
        err = fmt("failed to create socket: %s", err)
        return nil, err, nil
    end

    sock:settimeouts(opts.connect_timeout, opts.send_timeout, opts.read_timeout)

    if opts.uds then
        ok, err = sock:connect(opts.host, { pool_size = opts.keepalive_size })
    else
        ok, err = sock:connect(opts.host, opts.port, { pool_size = opts.keepalive_size })
    end
    if not ok then
        sock:close()
        err = fmt("failed to connect to t1k server %s: %s", server, err)
        return ok, err, nil
    end
    nlog(debug_fmt("successfully connected to t1k server %s", server))

    count, err = sock:getreusedtimes()
    if not count then
        nlog(warn_fmt("failed to get reused times from t1k server %s: %s", server, err))
    end

    if count == 0 then
        ok, err = sock:setoption("keepalive", true)
        if not ok then
            nlog(warn_fmt("failed to set keepalive for t1k server %s: %s", server, err))
        end
        ok, err = sock:setoption("reuseaddr", true)
        if not ok then
            nlog(warn_fmt("failed to set reuseaddr for t1k server %s: %s", server, err))
        end
        if not opts.uds then
            ok, err = sock:setoption("tcp-nodelay", true)
            if not ok then
                nlog(warn_fmt("failed to set tcp-nodelay for t1k server %s: %s", server, err))
            end
        end
    end

    return true, nil, sock
end

local function receive_data(sock, server, ignore_ret)
    local t
    if not ignore_ret then
        t = {}
    end

    local is_first_packet = true
    local finished

    repeat
        local err
        local tag, length, packet, data

        packet, err = sock:receive(consts.T1K_HEADER_SIZE)
        if err then
            err = fmt("failed to receive info packet from t1k server %s: %s", server, err)
            return nil, err, nil
        end
        if not packet then
            err = fmt("empty packet from t1k server %s", server)
            return nil, err, nil
        end

        if is_first_packet then
            if not utils.is_mask_first(byte(packet, 1, 1)) then
                err = fmt("first packet is not MASK_FIRST from t1k server %s", server)
                return nil, err, nil
            end
            is_first_packet = false
        end

        finished, tag, length = utils.packet_parser(packet)
        nlog(debug_fmt("received packet from t1k server %s: finished=%s, tag=0x%02X, length=%d", server, tostring(finished), tag, length))
        if length > 0 then
            data, err = sock:receive(length)
            if err then
                err = fmt("failed to receive data from t1k server %s: %s", server, err)
                return nil, err, nil
            end
            if not data or #data ~= length then
                err = fmt("incomplete data from t1k server %s: expected length %d, got %d", server, length, data and #data or 0)
                return nil, err, nil
            end
            if t then
                t[tag] = data
            end
        end

    until (finished)

    return true, nil, t
end

function _M.do_socket(premature, opts, payload, ignore_ret)
    if premature then
        nlog(warn_fmt("socket operation prematurely aborted"))
        return true
    end

    local ok, err
    local t, sock, server

    if opts.uds then
        server = opts.host
    else
        server = fmt("%s:%d", opts.host, opts.port)
    end

    ok, err, sock = get_socket(opts, server)
    if not ok then
        err = fmt("failed to get socket: %s", err)
        return ok, err, nil
    end

    local payload_len = payload and #payload or 0
    if not payload or type(payload) ~= "table" or payload_len == 0 then
        err = fmt("invalid payload to send to t1k server: table expected, got %s", type(payload))
        return false, err, nil
    end

    for index, item in ipairs(payload) do
        if type(item) ~= "table" then
            return false, fmt("invalid payload item at index %d: table expected, got %s", index, type(item)), nil
        end
        if type(item.tag) ~= "number" then
            return false, fmt("invalid tag in payload item at index %d: number expected, got %s", index, type(item.tag)), nil
        end
        if item.data ~= nil and type(item.data) ~= "string" and type(item.data) ~= "table" then
            return false, fmt("invalid data in payload item at index %d: string or table expected, got %s", index, type(item.data)), nil
        end

        if item.data ~= nil then
            local tag = item.tag
            if index == 1 then
                tag = bor(tag, consts.MASK_FIRST)
            end
            if index == payload_len then
                tag = bor(tag, consts.MASK_LAST)
            end

            ok, err = sock:send({ char(tag), utils.item_to_char_length(item.data), item.data })
            if not ok then
                sock:close()
                err = fmt("failed to send 0x%02X data to t1k server %s: %s", item.tag, server, err)
                return ok, err, nil
            end
        end
    end

    ok, err, t = receive_data(sock, server, ignore_ret)
    if not ok then
        sock:close()
        return ok, err, nil
    end

    ok, err = sock:setkeepalive(opts.keepalive_timeout)
    if not ok then
        sock:close()
        nlog(warn_fmt("failed to set keepalive for t1k server %s: %s", server, err))
    end

    return true, nil, t
end

return _M
