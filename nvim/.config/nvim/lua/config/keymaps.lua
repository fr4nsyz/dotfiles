-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Swap replace-letter command from 'r' to 's'
vim.keymap.set("n", "s", "r", { noremap = true, silent = true }) -- 's' now replaces a character
vim.keymap.set("n", "r", "<Nop>", { noremap = true, silent = true }) -- disable original 'r'
