return {
  -- add gruvbox
  { "miikanissi/modus-themes.nvim", priority = 1000 },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "modus",
    },
  },
}
