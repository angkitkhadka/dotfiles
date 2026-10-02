return {
  {
    "LazyVim/LazyVim",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "typescript", "typescriptreact" },
        callback = function(args)
          vim.b[args.buf].autoformat = false
        end,
      })
    end,
  },
}
