local tbl = require("vmark.tbl")
local str = require("vmark.str")

local state = {}
local M = {}

local MAX_LINE_LENGTH = 1024

local PATH_SEP = vim.fn.has("win32") == 1
    and "\\"
    or "/"

local function dirname(path)
    return vim.fn.fnamemodify(path, ":h")
end

--- @class VerboseMark
local VerboseMark = {}

function VerboseMark:rename()
end

function VerboseMark:edit()
end

function VerboseMark:delete()
end

--- @param bufnr integer
local function updateExtmarks(bufnr)
    state.items[bufnr] = tbl.filter(
        tbl.get(state.items, bufnr, {}),
        function(item)
            local mark = vim.api.nvim_buf_get_extmark_by_id(
                item.bufnr, state.nsid, item.id, {})
            if not mark[1] then
                return false
            end
            item.lnum = mark[1] + 1
            return true
        end
    )
end

--- @class VirtualMarkDetails
--- @field text string

--- @class VirtualMarkSetupOpts
--- @field format? fun(VirtualMarkDetails): vim.api.keyset.set_extmark

--- @param opts VirtualMarkSetupOpts
function M.setup(opts)
    opts = opts or {}

    state.items = {}
    state.marksDir = table.concat({
        vim.fn.stdpath("data"),
        "virtual-mark.nvim",
        "marks"
    }, PATH_SEP)
    state.nsid = vim.api.nvim_create_namespace("vmark.nvim")

    -- ◼
    state.format = opts.format or function(details)
        return {
            virt_text = {{
                " " .. details.text .. " ", "Title"
            }},
            hl_mode = "combine",
            virt_text_pos = "right_align",
            number_hl_group = "CursorLineSign",
            sign_hl_group = "CursorLineNr",
            line_hl_group = "CursorLine",
            cursorline_hl_group = "CursorLine",
            sign_text = ">>",
        }
    end

    vim.api.nvim_create_augroup("vmark.nvim", { clear = true })
    vim.api.nvim_create_autocmd({ "BufRead" }, {
        group = "vmark.nvim",
        pattern = "*",
        callback = function()
            M.load()
        end
    })
    vim.api.nvim_create_autocmd({ "BufWrite" }, {
        group = "vmark.nvim",
        pattern = "*",
        callback = function()
            M.save()
        end
    })
end

--- @param bufnr integer
--- @param lnum integer
--- @param text string
--- @return integer bufnr
local function addExtmark(bufnr, lnum, text)
    local opts = tbl.spread({
        invalidate = true,
    }, state.format({
        bufnr = bufnr,
        text = text,
        lnum = lnum,
    }))
    return vim.api.nvim_buf_set_extmark(
        bufnr, state.nsid, lnum - 1, 0, opts)
end

function M.removeUnderCursor()
    M.remove(vim.fn.bufnr(), vim.fn.line("."))
end

function M.echoUnderCursor()
    M.echo(vim.fn.bufnr(), vim.fn.line("."))
end

--- @param bufnr integer
--- @param lnum integer
function M.remove(bufnr, lnum)
    local marks = table(vim.api.nvim_buf_get_extmarks(
        0, state.nsid, {lnum - 1, 0}, {lnum - 1, 0}, { }))
    local markIds = tbl.map(marks, function(mark)
        return mark[1]
    end)
    tbl.forEach(markIds, function(id)
        vim.api.nvim_buf_del_extmark(0, state.nsid, id)
    end)
    state.items[bufnr] = tbl.filter(
        tbl.get(state.items, bufnr, {}),
        function(item)
            return not tbl.contains(markIds, item.id)
        end
    )
    M.save()
end

--- @param bufnr integer
--- @param lnum integer
function M.echo(bufnr, lnum)
    local marks = table(vim.api.nvim_buf_get_extmarks(
        0, state.nsid, {lnum - 1, 0}, {lnum - 1, 0}, { }))
    local markIds = tbl.map(marks, function(mark)
        return mark[1]
    end)
    local item = tbl.find(
        tbl.get(state.items, bufnr, {}),
        function(item)
            return tbl.contains(markIds, item.id)
        end
    )
    if item then
        vim.api.nvim_echo({{item.text, "Normal"}}, false, {})
    end
end

function M.create()
    vim.ui.input({ prompt = "> " }, function(result)
        if not result or result == "" then
            return
        end

        local lnum = vim.fn.line(".")
        local bufnr = vim.fn.bufnr()

        updateExtmarks(bufnr)
        local existingItem, existingIdx = tbl.find(
            tbl.get(state.items, bufnr, {}),
            function(item)
                return item.lnum == lnum
            end
        )
        if existingItem then
            state.items[bufnr] = tbl.filter(state.items[bufnr],
                function(item) return item ~= existingIdx end)
            vim.api.nvim_buf_del_extmark(
                bufnr, state.nsid, existingItem.id)
        end
        table.insert(
            tbl.get(state.items, bufnr, {}),
            {
                id = addExtmark(bufnr, lnum, result),
                lnum = lnum,
                bufnr = bufnr,
                text = result
            }
        )
        M.save()
    end)
end

--- @param path string
--- @param root string
local function recursivelyDeleteEmptyDirectories(path, root)
    if str.index(path, root .. PATH_SEP) == 1
        and vim.fn.delete(path, "d") == 0
    then
        recursivelyDeleteEmptyDirectories(dirname(path), root)
    end
end

--- @param bufnr? integer
function M.save(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    updateExtmarks(bufnr)
    bufnr = bufnr or vim.fn.bufnr()
    local bufName = vim.api.nvim_buf_get_name(bufnr)
    if not bufName or bufName == "" then
        return
    end
    local lines = vim.api.nvim_buf_get_lines(
        bufnr, 0, -1, true)
    local items = tbl.map(
        tbl.get(state.items, bufnr, {}),
        function(item)
            return {
                lnum = item.lnum,
                text = item.text,
                line = #lines[item.lnum] <= MAX_LINE_LENGTH
                    and lines[item.lnum]
                    or nil
            }
        end)
    local fname = state.marksDir
        .. vim.api.nvim_buf_get_name(bufnr)
    if #items == 0 then
        if vim.fn.filereadable(fname) == 1 then
            vim.fn.delete(fname)
            recursivelyDeleteEmptyDirectories(dirname(fname), state.marksDir)
        end
        return
    end
    local json = vim.json.encode(items)
    local parent = dirname(fname)
    if vim.fn.isdirectory(parent) == 0 then
        vim.fn.mkdir(parent, "p")
    end
    vim.fn.writefile({json}, fname)
end

--- @param bufnr? integer
function M.load(bufnr)
    if vim.fn.isdirectory(state.marksDir) == 0 then
        return
    end
    bufnr = bufnr or vim.fn.bufnr()
    local bufName = vim.api.nvim_buf_get_name(bufnr)
    if not bufName or bufName == "" then
        return
    end
    local fname = state.marksDir
        .. vim.api.nvim_buf_get_name(bufnr)
    if vim.fn.filereadable(fname) == 0 then
        return
    end
    local json = vim.fn.readfile(fname)[1]
    if not json then
        return
    end
    vim.api.nvim_buf_clear_namespace(bufnr, state.nsid, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(
        bufnr, 0, -1, true)
    local items = table(vim.json.decode(json))
    local validItems = tbl.filter(items, function(item)
        return not item.line or item.line == lines[item.lnum]
    end)
    state.items[bufnr] = tbl.map(validItems, function(item)
        return {
            id = addExtmark(bufnr, item.lnum, item.text),
            lnum = item.lnum,
            bufnr = bufnr,
            text = item.text
        }
    end)
    if #items ~= #validItems then
        M.save(bufnr)
    end
end

--- @param allBuffers? boolean
function M.quickfix(allBuffers)
    if allBuffers then
        local results = {}
        for bufnr in pairs(state.items) do
            updateExtmarks(bufnr)
            results = tbl.concat(results, state.items[bufnr])
        end
        vim.fn.setqflist(results)
        vim.cmd.copen()
    else
        local bufnr = vim.fn.bufnr()
        updateExtmarks(bufnr)
        local qflist = tbl.get(state.items, bufnr, {})
        vim.fn.setqflist(qflist)
        vim.cmd.copen()
    end
end

--- @param path string
--- @param results tablelib
local function recursiveReaddir(path, results)
    for _, name in ipairs(vim.fn.readdir(path)) do
        local childPath = path .. PATH_SEP .. name
        if vim.fn.isdirectory(childPath) == 1 then
            recursiveReaddir(childPath, results)
        else
            table.insert(results, childPath)
        end
    end
end

function M.recursiveQuickfix()
    local cwd = vim.fn.getcwd()
    local root = state.marksDir .. cwd
    local paths = {}
    if vim.fn.isdirectory(root) == 1 then
        recursiveReaddir(root, paths)
    end
    local qflist = {}
    for _, path in ipairs(paths) do
        local json = vim.fn.readfile(path)[1]
        if json then
            local items = table(vim.json.decode(json))
            local fpath = cwd .. str.slice(path, #root + 1)
            for _, item in ipairs(items) do
                table.insert(qflist, {
                    lnum = item.lnum,
                    filename = fpath,
                    text = item.text
                })
            end
        end
    end
    vim.fn.setqflist(qflist)
    vim.cmd.copen()
end

function M.next()
    local curpos = vim.fn.getcurpos()
    local pos = { curpos[2] - 1, -1 }
    local marks = vim.api.nvim_buf_get_extmarks(
        0, state.nsid, pos, -1, {})
    local mark = marks[1]
    if mark then
        vim.fn.setpos(".", { 0, mark[2] + 1, 1, 0 })
    end
end

function M.prev()
    local curpos = vim.fn.getcurpos()
    if curpos[2] <= 1 then
        return
    end
    local pos = { curpos[2] - 2, -1 }
    local marks = vim.api.nvim_buf_get_extmarks(
        0, state.nsid, pos, 0, {})
    local mark = marks[1]
    if mark then
        vim.fn.setpos(".", { 0, mark[2] + 1, 1, 0 })
    end
end

return M
