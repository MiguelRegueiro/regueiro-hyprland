vim.opt.clipboard = "unnamedplus"
-- Avoid recovery prompts from stale swap files after a terminal is closed.
vim.opt.swapfile = false
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true

local function set_transparent_background()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "CursorLine",
    "EndOfBuffer",
  }

  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end

  vim.api.nvim_set_hl(0, "LineNr", { fg = "#898dad" })
  vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#898dad" })
  vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#898dad" })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#d6dcff", bold = true })
  vim.api.nvim_set_hl(0, "TabLine", { fg = "#898dad", bg = "#0c0c12" })
  vim.api.nvim_set_hl(0, "TabLineSel", { fg = "#d6dcff", bg = "#20243a", bold = true })
  vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
  vim.api.nvim_set_hl(0, "TabLineClose", { fg = "#c0c6e2", bg = "#0c0c12" })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = set_transparent_background,
})

set_transparent_background()

vim.opt.showtabline = 2

local function close_tab(tab)
  if vim.bo.modified then
    vim.api.nvim_echo({ { "Unsaved changes", "WarningMsg" } }, false, {})
    return
  end

  local command = vim.fn.tabpagenr("$") == 1 and "quit" or (tab .. "tabclose")
  local ok, err = pcall(vim.cmd, command)
  if not ok then
    if tostring(err):find("E37", 1, true) then
      vim.api.nvim_echo({ { "Unsaved changes", "WarningMsg" } }, false, {})
    else
      vim.api.nvim_echo({ { tostring(err), "ErrorMsg" } }, false, {})
    end
  end
end

function _G.CleanSelectTab(tab)
  vim.cmd(tab .. "tabnext")
end

function _G.CleanCloseTab(tab, _, button)
  if button == "l" then
    vim.schedule(function()
      close_tab(tab)
    end)
  end
end

function _G.CleanCloseCurrentTab()
  close_tab(vim.fn.tabpagenr())
end

function _G.CleanTabline()
  local labels = {}
  local current = vim.fn.tabpagenr()

  for tab = 1, vim.fn.tabpagenr("$") do
    local buffer = vim.fn.tabpagebuflist(tab)[vim.fn.tabpagewinnr(tab)]
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buffer), ":t")
    if name == "" then
      name = "[No Name]"
    end
    name = name:gsub("%%", "%%%%")
    local group = tab == current and "%#TabLineSel#" or "%#TabLine#"
    labels[#labels + 1] = string.format(
      "%s%%%d@v:lua.CleanSelectTab@  %s %%X%s%%%d@v:lua.CleanCloseTab@× %%X",
      group,
      tab,
      name,
      group,
      tab
    )
  end

  return table.concat(labels) .. "%#TabLineFill#%="
end

vim.opt.tabline = "%!v:lua.CleanTabline()"

vim.keymap.set("n", "<C-w>", function()
  _G.CleanCloseCurrentTab()
end, { silent = true, nowait = true, desc = "Close current tab" })


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
