local _M = {
    _VERSION = '1.0.0',
}

local metatable = { __index = _M }

function _M:new(o)
    o = o or {}
    setmetatable(o, metatable)
    return o
end

function _M:add(v)
    self[#self + 1] = v
end

function _M:len()
    local len = 0
    for _, v in ipairs(self) do
        len = len + #v
    end
    return len
end

return _M
