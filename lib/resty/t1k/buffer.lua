local _M = {
    _VERSION = '1.0.0',
}

function _M:new ()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:add_lf ()
    self:add("\x0a")
end

function _M:add_crlf ()
    self:add("\x0d\x0a")
end

function _M:add (...)
    for _, v in ipairs({ ... }) do
        table.insert(self, v)
    end
end

function _M:add_kv_lf (k, v)
    self:add(k, ":", v)
    self:add_lf()
end

function _M:add_kv_crlf (k, v)
    self:add(k, ": ", v)
    self:add_crlf()
end

function _M:tostring (sep, i, j)
    return table.concat(self, sep, i, j)
end

function _M:len()
    local l = 0
    for _, v in ipairs(self) do
        l = l + #v
    end
    return l
end

return _M
