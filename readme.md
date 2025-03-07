# vmark.nvim

Descriptive, persistent marks in Neovim with quickfix list capability.

<img width="471" alt="vmark" src="https://github.com/user-attachments/assets/631aa449-a60f-4c2b-a080-dce7fb2a6c2c" />

### Example Config (lazy.nvim)

```lua
{
    "jake-stewart/vmark.nvim",
    event = "BufRead",
    config = function()
        local vmark = require("vmark")

        vmark.setup({
            format = function(details)
                -- see `:h nvim_buf_set_extmark()` for configuration options
                return {
                    virt_text = {{ " ◼ " .. details.text .. " ", "DiagnosticInfo" }},
                    hl_mode = "combine",
                    virt_text_pos = "eol",
                    sign_hl_group = "DiagnosticInfo",
                    sign_text = ">>",
                }
            end
        })

        -- create a new vmark at the cursor position
        vim.keymap.set("n", "ma", vmark.create)

        -- delete the vmark at the cursor position
        vim.keymap.set("n", "md", vmark.removeUnderCursor)

        -- open the quickfix with all marks found recursively from current directory
        vim.keymap.set("n", "mo", vmark.recursiveQuickfix)

        -- print the vmark text at the cursor position
        vim.keymap.set("n", "me", vmark.echoUnderCursor)

        -- jump to the next/prev vmark in the document
        vim.keymap.set({"n", "v", "o"}, "mk", vmark.prev)
        vim.keymap.set({"n", "v", "o"}, "mj", vmark.next)
    end
}
```
