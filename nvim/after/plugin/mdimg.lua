-- Drag an image onto a markdown buffer: the terminal drops in its
-- backslash-escaped path, which this swaps for a markdown link after copying the
-- image into a sibling assets/ or imgs/ (imgs/ is created if neither exists).
local EXT = [[png\|jpe\?g\|gif\|webp\|svg\|bmp\|heic\|avif\|tiff\?]]
local PAT = [[\c\%(^\|\s\)\@<=\%(\~\|\.\{1,2}\)\?/\%([^ \t\\]\|\\.\)*\.\%(]] .. EXT .. [[\)\%(\s\|$\)\@=]]

local function slug(name)
  return (name:lower():gsub("[^%w.]+", "-"):gsub("^-+", ""):gsub("-+$", ""))
end

local function target_dir()
  local base = vim.fn.expand("%:p:h")
  for _, name in ipairs({ "assets", "imgs" }) do
    if vim.fn.isdirectory(base .. "/" .. name) == 1 then return base .. "/" .. name end
  end
  vim.fn.mkdir(base .. "/imgs", "p")
  return base .. "/imgs"
end

local busy = false
local function on_drop()
  if busy or vim.bo.filetype ~= "markdown" then return end
  local row, line = vim.fn.line("."), vim.fn.getline(".")
  local raw, s, e = unpack(vim.fn.matchstrpos(line, PAT))
  if raw == "" then return end
  local src = vim.fn.fnamemodify((raw:gsub("\\(.)", "%1")), ":p")
  if vim.fn.filereadable(src) == 0 then return end

  busy = true
  vim.schedule(function()
    local dir = target_dir()
    local ext = vim.fn.fnamemodify(src, ":e")
    vim.ui.input({ prompt = "Image name: ", default = slug(vim.fn.fnamemodify(src, ":t")) }, function(name)
      busy = false
      name = slug(name or "")
      if name == "" then return end
      if not name:find("%.") then name = name .. "." .. ext end

      local dest, stem, i = dir .. "/" .. name, name:gsub("%.[^.]*$", ""), 1
      while vim.uv.fs_stat(dest) do
        dest, i = ("%s/%s-%d.%s"):format(dir, stem, i, ext), i + 1
      end
      local ok, err = vim.uv.fs_copyfile(src, dest)
      if not ok then return vim.notify("mdimg: " .. err, vim.log.levels.ERROR) end

      local rel = ("%s/%s"):format(vim.fn.fnamemodify(dir, ":t"), vim.fn.fnamemodify(dest, ":t"))
      local link = ("![%s](%s)"):format((stem:gsub("[-_]", " ")), rel)
      vim.api.nvim_buf_set_text(0, row - 1, s, row - 1, e, { link })
      vim.api.nvim_win_set_cursor(0, { row, s + #link })
    end)
  end)
end

-- iTerm2 sends a drag as a bracketed paste, which vim.paste sees in any mode.
-- TextChangedI is the fallback for a terminal that sends plain keystrokes.
local paste = vim.paste
vim.paste = function(lines, phase)
  local ok = paste(lines, phase)
  if phase == -1 or phase == 3 then vim.schedule(on_drop) end
  return ok
end

vim.api.nvim_create_autocmd("TextChangedI", { pattern = "*.md", callback = on_drop })
vim.api.nvim_create_user_command("ImgDrop", on_drop, {})
