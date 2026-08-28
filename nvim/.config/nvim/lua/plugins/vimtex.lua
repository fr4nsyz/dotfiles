return {
  {
    "lervag/vimtex",
    lazy = false, -- we don't want to lazy load VimTeX
    -- tag = "v2.15", -- uncomment to pin to a specific release
    init = function()
      -- VimTeX configuration goes here, e.g.
      if vim.fn.has("mac") == 1 then
        -- macOS zathura builds lack xdotool; use the simple variant.
        -- This Homebrew build is also built without synctex, so disable it
        -- (the -x/--synctex args would otherwise print an error and be ignored).
        vim.g.vimtex_view_method = "zathura_simple"
        vim.g.vimtex_view_zathura_use_synctex = 0
      else
        vim.g.vimtex_view_method = "zathura"
      end
    end,
  },
}
