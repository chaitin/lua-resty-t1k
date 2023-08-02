local _M = {
    _VERSION = '1.0.0',
}

function _M:new (o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:add (...)
    for _, v in ipairs({ ... }) do
        table.insert(self, v)
    end
end

function _M:add_crlf ()
    self:add("\r\n")
end

function _M:add_kv_crlf (k, v)
    self:add(k, ": ", v, "\r\n")
end

function _M:len()
    local len = 0
    for _, v in ipairs(self) do
        len = len + #v
    end
    return len
end

return _M
