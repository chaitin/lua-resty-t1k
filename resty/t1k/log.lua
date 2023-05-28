local _M = {
    _VERSION = '1.0.0'
}

local fmt = string.format

local ERR = ngx.ERR
local WARN = ngx.WARN
local DEBUG = ngx.DEBUG

local function log(formatstring, ...)
    return fmt("lua-resty-t1k: " .. formatstring, ...)
end

function _M.err_fmt(formatstring, ...)
    return ERR, log(formatstring, ...)
end

function _M.warn_fmt(formatstring, ...)
    return WARN, log(formatstring, ...)
end

function _M.debug_fmt(formatstring, ...)
    return DEBUG, log(formatstring, ...)
end

return _M
