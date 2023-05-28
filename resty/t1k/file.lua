local _M = {
    _VERSION = '1.0.0'
}

function _M.read(p)
    local f, err = io.open(p, "rb")
    if not f or err then
        return nil, err, nil
    end

    local c = f:read("*all")
    f:close()
    return true, nil, c
end

return _M
