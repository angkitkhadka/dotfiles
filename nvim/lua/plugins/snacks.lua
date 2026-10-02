-- this file configures snacks + persistence of hidden and ignored files..
local file = vim.fn.stdpath("state") .. "/snacks_picker.json"

-- load saved values, defaulting both to true
local ok, saved = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
end)
local state = vim.tbl_extend("force", { hidden = true, ignored = true }, ok and saved or {})

local function toggle(key)
  return function(picker)
    state[key] = not state[key]

    -- session: newly opened pickers read these values
    local sources = require("snacks").config.picker.sources
    for _, name in ipairs({ "explorer", "files" }) do
      sources[name][key] = state[key]
    end

    -- disk: survives restarting Neovim
    vim.fn.writefile({ vim.json.encode(state) }, file)

    picker.opts[key] = state[key]
    picker:find()
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    image = {
      enabled = true,
      formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "pdf", "icns" },
      doc = { enabled = true, float = false, max_width = 80, max_height = 40 },
    },
    picker = {
      actions = {
        persist_hidden = toggle("hidden"),
        persist_ignored = toggle("ignored"),
      },
      sources = {
        explorer = {
          hidden = state.hidden,
          ignored = state.ignored,
          win = { list = { keys = { H = "persist_hidden", I = "persist_ignored" } } },
        },
        files = {
          hidden = state.hidden,
          ignored = state.ignored,
          win = {
            input = {
              keys = {
                ["<a-h>"] = { "persist_hidden", mode = { "n", "i" } },
                ["<a-i>"] = { "persist_ignored", mode = { "n", "i" } },
              },
            },
          },
        },
      },
    },
  },
}
