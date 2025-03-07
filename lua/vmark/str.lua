local str = {}

--- @param container string | table
--- @param index number
local function wrapContainerIndex(container, index)
    return index < 0 and #container + index + 1 or index
end

--- @param len number
--- @param start? number
--- @param stop? number
local function indexRange(len, start, stop)
    start = start or 1
    stop = stop or len
    if start < 0 then
        start = len + start + 1
    end
    if stop < 0 then
        stop = len + stop + 1
    end
    start = math.max(1, start)
    stop = math.min(len, stop)
    return start, stop
end

--- @param s string
--- @param substring string
--- @param startAt? integer
--- @return integer | nil
function str.index(s, substring, startAt)
    return s:find(
        substring,
        wrapContainerIndex(s, startAt or 1),
        true
    )
end

--- @param s string
--- @param start? integer
--- @param stop? integer
--- @return string
function str.slice(s, start, stop)
    start, stop = indexRange(#s, start, stop)
    return s:sub(start, stop)
end

return str
