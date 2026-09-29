return {
  -- Disable format on save for TypeScript
  {
    "neovim/nvim-lspconfig",
    config = function()
      local augroup = vim.api.nvim_create_augroup("DisableTSFormatOnSave", { clear = true })

      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        pattern = { "*.ts", "*.tsx" },
        callback = function()
          local clients = vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })
          for _, client in ipairs(clients) do
            if client.supports_method("textDocument/formatting") then
              -- temporarily disable formatting for this save
              client.request_sync("textDocument/formatting", {}, 1000, vim.api.nvim_get_current_buf())
            end
          end
        end,
      })
    end,
  },
}
