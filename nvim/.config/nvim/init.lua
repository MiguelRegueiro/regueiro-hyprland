vim.opt.clipboard = "unnamedplus"

local opts = { noremap = true, silent = true }

vim.keymap.set("n", "<C-a>", "ggVG", opts)
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", opts)
