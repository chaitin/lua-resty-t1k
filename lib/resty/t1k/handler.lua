local consts = require "resty.t1k.constants"

local fmt = string.format

local ngx = ngx

local _M = {
    _VERSION = '1.0.0'
}

function _M.handle(t)
    t = t or {}
    local action = t["action"]
    local extra_header = t["extra_header"]

    if extra_header then
        ngx.ctx.t1k_extra_header = extra_header
    end

    if action == consts.ACTION_PASSED then
        return true, nil
    elseif action == consts.ACTION_BLOCKED then
        ngx.status = t["status"] or ngx.HTTP_FORBIDDEN
        ngx.header.content_type = consts.BLOCK_CONTENT_TYPE
        ngx.say(fmt(consts.BLOCK_CONTENT_FORMAT, ngx.status, t["event_id"]))

        return ngx.exit(ngx.status)
    else
        local err = fmt("unknown action from t1k server: %s", action)
        return nil, err
    end
end

return _M
