return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    servers = {
      gopls = {
        filetypes = { "go", "gomod" },
        root_dir = require("lspconfig.util").root_pattern("go.work", "go.mod", ".git"),
        settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              nilness = true,
            },
            staticcheck = true,
          },
        },
      },
    },
    setup = {
      gopls = function(_, bufnr)
        local opts = { noremap = true, silent = true }
        vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
        vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
      end,
    },
  },
}
