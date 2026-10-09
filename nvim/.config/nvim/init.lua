vim.opt.clipboard = "unnamedplus"
-- Avoid recovery prompts from stale swap files after a terminal is closed.
vim.opt.swapfile = false

local function set_transparent_background()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "EndOfBuffer",
  }

  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_transparent_background,
})

set_transparent_background()



-- Ctrl+A selects all text
vim.keymap.set("n", "<C-a>", "ggVG", { noremap = true, silent = true })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { noremap = true, silent = true })

vim.keymap.set("n", "<F13>", "gt", {
  noremap = true,
  silent = true,
  desc = "Next tab",
})

vim.keymap.set("n", "<F14>", "gT", {
  noremap = true,
  silent = true,
  desc = "Previous tab",
})
