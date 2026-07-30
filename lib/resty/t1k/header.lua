local consts = require "resty.t1k.constants"
local log = require "resty.t1k.log"

local _M = {
    _VERSION = '1.0.0'
}

local find = string.find
local sub = string.sub

local ngx = ngx
local nlog = ngx.log

local debug_fmt = log.debug_fmt

local function parse_extra_header(extra_header)
    local t = {}
    local idx = 1

    while (idx <= #extra_header) do
        local key, val
        local _, to = find(extra_header, ":", idx)
        if to == 0 then
            break
        else
            key = sub(extra_header, idx, to - 1)
        end

        idx = to + 1
        _, to = find(extra_header, "\n", idx)
        if to == 0 then
            break
        else
            val = sub(extra_header, idx, to - 1)
        end

        t[key] = val
        idx = to + 1
    end

    return t
end

local function set_extra_header()
    local extra_header = ngx.ctx.t1k_extra_header
    if extra_header == nil or extra_header == "" then
        return
    end
    local header_table = parse_extra_header(extra_header)
    for k, v in pairs(header_table) do
        if k ~= nil and v ~= nil then
            ngx.header[k] = v
        end
    end
end

local function get_content_type()
    local content_type = ngx.resp.get_headers()["Content-Type"]
    if content_type == nil then
        return nil
    end

    if type(content_type) == "table" then
        content_type = content_type[1]
    end

    local sep_pos = find(content_type, ";")
    if sep_pos ~= nil and sep_pos > 1 then
        content_type = sub(content_type, 1, sep_pos - 1)
    end

    return content_type:lower()
end

local function filter_content_type()
    local opts = ngx.ctx.t1k_opts
    if opts == nil or not opts.log_resp or ngx.ctx.tx_skipped then
        nlog(debug_fmt("skip content type filtering"))
        return
    end

    local content_type = get_content_type()
    if content_type == nil or content_type == "" then
        return
    end
    if opts.ignored_content_types and opts.ignored_content_types[content_type] then
        ngx.ctx.tx_skipped = true
        return
    elseif consts.DEFAULT_IGNORED_CONTENT_TYPES[content_type] then
        ngx.ctx.tx_skipped = true
        return
    end
end

function _M.do_header_filter()
    set_extra_header()
    filter_content_type()
end

return _M
