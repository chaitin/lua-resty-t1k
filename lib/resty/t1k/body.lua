local buffer = require "resty.t1k.buffer"
local log = require "resty.t1k.log"

local _M = {
    _VERSION = '1.0.0'
}

local sub = string.sub

local ngx = ngx
local nlog = ngx.log

local debug_fmt = log.debug_fmt

function _M.do_body_filter()
    local opts = ngx.ctx.t1k_opts

    if ngx.ctx.t1k_resp_begin_time == nil then
        ngx.update_time()
        ngx.ctx.t1k_resp_begin_time = ngx.now() * 1000000
    end

    if ngx.ctx.t1k_resp_limit == nil then
        if not opts or not opts.log_resp or ngx.ctx.tx_skipped then
            nlog(debug_fmt("skip response body buffering"))
            ngx.ctx.t1k_resp_limit = -1
            return
        end

        local limit = opts.resp_body_size and (opts.resp_body_size * 1024) or 0
        ngx.ctx.t1k_resp_limit = limit

        if limit <= 0 then
            nlog(debug_fmt("skip response body buffering for non-positive limit: %d", ngx.ctx.t1k_resp_limit))
            return
        end

        ngx.ctx.t1k_resp_body = buffer:new()
        ngx.ctx.t1k_total_resp_body_size = 0
        ngx.ctx.t1k_buffered_resp_body_size = 0
    elseif ngx.ctx.t1k_resp_limit <= 0 then
        nlog(debug_fmt("skip response body buffering for non-positive limit: %d", ngx.ctx.t1k_resp_limit))
        return
    end

    local chunk, eof = ngx.arg[1], ngx.arg[2]
    local chunk_len = chunk and #chunk or 0

    local total_size = ngx.ctx.t1k_total_resp_body_size
    local buffered_size = ngx.ctx.t1k_buffered_resp_body_size
    local limit = ngx.ctx.t1k_resp_limit

    total_size = total_size + chunk_len
    ngx.ctx.t1k_total_resp_body_size = total_size

    if chunk_len > 0 and buffered_size < limit then
        local remaining_space = limit - buffered_size

        if chunk_len > remaining_space then
            ngx.ctx.t1k_resp_body:add(sub(chunk, 1, remaining_space))
            buffered_size = limit
        else
            ngx.ctx.t1k_resp_body:add(chunk)
            buffered_size = buffered_size + chunk_len
        end

        ngx.ctx.t1k_buffered_resp_body_size = buffered_size
    end

    if eof then
        nlog(debug_fmt("response body received completely, total size: %d bytes, truncated size: %d bytes", total_size, buffered_size))
    end
end

return _M
