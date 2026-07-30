local _M = {
    _VERSION = '1.0.0',
}

function _M:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function _M:add(...)
    local n = select('#', ...)
    local base = #self

    if n == 1 then
        self[base + 1] = ...
    elseif n == 2 then
        local a, b = ...
        self[base + 1] = a
        self[base + 2] = b
    elseif n == 3 then
        local a, b, c = ...
        self[base + 1] = a
        self[base + 2] = b
        self[base + 3] = c
    elseif n == 4 then
        local a, b, c, d = ...
        self[base + 1] = a
        self[base + 2] = b
        self[base + 3] = c
        self[base + 4] = d
    elseif n > 0 then
        for i = 1, n do
            self[base + i] = select(i, ...)
        end
    end
end

function _M:len()
    local len = 0
    for _, v in ipairs(self) do
        len = len + #v
    end
    return len
end

function _M:tostring()
    return table.concat(self)
end

return _M
