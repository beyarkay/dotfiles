-- Markdown drawn in place: treesitter highlighting plus render-markdown.nvim.
-- Off the cursor line a link reads as an underlined [text]; the cursor line
-- always shows the raw source.
--   <leader>mr  toggle the rendering in this buffer
--   <leader>mp  :MdPreview, open the file rendered in Firefox (reloads on save)
local ok, rm = pcall(require, "render-markdown")
if not ok then return end

-- Neovim's markdown_inline query hides a link's brackets along with its URL,
-- and treats any [bracketed text] as a link. Keep the brackets of real links,
-- underlined with their text, and leave other bracketed text alone. If the
-- runtime query ever changes shape, it is left as it is.
local function keep_link_brackets()
  local parts = {}
  for _, f in ipairs(vim.treesitter.query.get_files("markdown_inline", "highlights")) do
    parts[#parts + 1] = table.concat(vim.fn.readfile(f), "\n")
  end
  local src = table.concat(parts, "\n")
  local edits = {
    { '(%(inline_link%s*%[)%s*"%["%s*"%]"', "%1" },
    { '(%(full_reference_link%s*%[)%s*"%["%s*"%]"', "%1" },
    { '(%(image%s*%[)%s*"!"%s*"%["%s*"%]"', "%1" },
    { '%(shortcut_link%s*%[%s*"%["%s*"%]"%s*%]%s*@markup%.link%s*%(#set! conceal ""%)%)', "" },
    { "\n  %(link_text%)\n", "\n" },
  }
  for _, e in ipairs(edits) do
    local n
    src, n = src:gsub(e[1], e[2])
    if n ~= 1 then return end
  end
  src = src .. [[

(inline_link ["[" (link_text) "]"] @markup.link.label)
(full_reference_link ["[" (link_text) "]"] @markup.link.label)
(collapsed_reference_link (link_text) @markup.link.label)
(image ["!" "[" "]"] @markup.link.label)
]]
  if pcall(vim.treesitter.query.parse, "markdown_inline", src) then
    vim.treesitter.query.set("markdown_inline", "highlights", src)
  end
end
keep_link_brackets()

-- onehalfdark: { gui fg, cterm fg, gui background tinted 15% towards fg }
local heading_colours = {
  { "#61afef", 75, "#314050" },
  { "#98c379", 114, "#39433e" },
  { "#e5c07b", 180, "#44423f" },
  { "#c678dd", 176, "#40374d" },
  { "#56b6c2", 73, "#2f4149" },
  { "#abb2bf", 188, "#3a3f4a" },
}

local function colours()
  local hl = vim.api.nvim_set_hl
  hl(0, "@markup.link.label.markdown_inline", { fg = "#61afef", ctermfg = 75, underline = true })
  hl(0, "@markup.link.markdown_inline", { fg = "#5c6370", ctermfg = 241 })
  hl(0, "@markup.link.url.markdown_inline", { fg = "#5c6370", ctermfg = 241 })
  for i, c in ipairs(heading_colours) do
    hl(0, "@markup.heading." .. i .. ".markdown", { fg = c[1], ctermfg = c[2], bold = true })
    hl(0, "RenderMarkdownH" .. i .. "Bg", { bg = c[3], ctermbg = 237 })
  end
  hl(0, "RenderMarkdownCode", { bg = "#2c313a", ctermbg = 237 })
  hl(0, "RenderMarkdownCodeInline", { bg = "#313640", ctermbg = 237 })
  hl(0, "RenderMarkdownChecked", { fg = "#98c379", ctermfg = 114 })
  hl(0, "RenderMarkdownUnchecked", { fg = "#919baa", ctermfg = 247 })
  hl(0, "RenderMarkdownTodo", { fg = "#e5c07b", ctermfg = 180 })
  hl(0, "RenderMarkdownDone", { fg = "#5c6370", ctermfg = 241, strikethrough = true })
end
colours()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colours })

-- The terminal font has no Nerd Font glyphs, so every icon is plain Unicode.
local no_icon = {}
for name in pairs(rm.default.link.custom) do no_icon[name] = { icon = "" } end
-- Callout titles are drawn over the raw [!NOTE], whose brackets now stay
-- visible, so pad each title to cover them.
local callouts = {}
for name, c in pairs(rm.default.callout) do
  local title = "▸ " .. c.rendered:gsub("^%S+%s+", "")
  callouts[name] = { rendered = title .. (" "):rep(#c.raw - vim.fn.strdisplaywidth(title)) }
end

rm.setup({
  render_modes = true,
  -- 2, not 3, so entities like &lt; show the character they stand for
  win_options = { conceallevel = { rendered = 2 } },
  latex = { enabled = false },
  heading = {
    sign = false,
    icons = { "▌ ", "▌ ", "▌ ", "▌ ", "▌ ", "▌ " },
  },
  -- Drawn text keeps the width of its raw source, so nothing jumps when the
  -- cursor line switches to raw: fences stay as thin bars, the language name
  -- sits where it does after ```, and a backtick becomes a padding space.
  code = {
    sign = false,
    language_icon = false,
    language_pad = 3,
    border = "thin",
    width = "block",
    right_pad = 4,
    min_width = 60,
    inline_pad = 1,
  },
  bullet = { icons = { "–", "–", "–", "–" } },
  -- `- [ ] task` draws as `    ☐ task`, the task text in the same column
  checkbox = {
    left_pad = 4,
    right_pad = 0,
    unchecked = { icon = "☐ " },
    checked = { icon = "☑ ", scope_highlight = "RenderMarkdownDone" },
    custom = {
      todo = { raw = "[-]", rendered = "◐ ", highlight = "RenderMarkdownTodo" },
      progress = { raw = "[~]", rendered = "◐ ", highlight = "RenderMarkdownTodo" },
      cancelled = { raw = "[/]", rendered = "☒ ", highlight = "RenderMarkdownUnchecked", scope_highlight = "RenderMarkdownDone" },
    },
  },
  link = {
    hyperlink = "",
    image = "",
    email = "",
    footnote = { icon = "" },
    wiki = { icon = "" },
    custom = no_icon,
  },
  callout = callouts,
  -- no html or yaml treesitter parsers are installed
  html = { enabled = false },
  yaml = { enabled = false },
  -- todo.nvim colours the `- [ ]` itself, so leave list markers to it
  overrides = {
    filetype = {
      ["markdown.todo"] = { checkbox = { enabled = false }, bullet = { enabled = false } },
    },
  },
})

-- Firefox preview: one bun server per nvim session renders any .md under
-- $HOME with pandoc and tells open pages to reload when their file changes.
local preview = { job = nil, url = nil, queue = {} }
local server = vim.fn.expand("~/.dotfiles/scripts/mdpreview.ts")

local function open_preview(path)
  vim.system({ "open", "-a", "Firefox", preview.url .. vim.uri_from_fname(path):sub(#"file://" + 1) })
end

local function md_preview()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then return vim.notify("MdPreview: buffer has no file", vim.log.levels.WARN) end
  vim.cmd("silent update")
  if preview.url then return open_preview(path) end
  table.insert(preview.queue, path)
  if preview.job then return end
  local bun = vim.fn.exepath("bun")
  if bun == "" then bun = vim.fn.expand("~/.bun/bin/bun") end
  preview.job = vim.fn.jobstart({ bun, server }, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if not preview.url and line:match("^http") then
          preview.url = line
          for _, p in ipairs(preview.queue) do open_preview(p) end
          preview.queue = {}
        end
      end
    end,
    on_stderr = function(_, data)
      local msg = vim.trim(table.concat(data, "\n"))
      if msg ~= "" then vim.schedule(function() vim.notify("MdPreview: " .. msg, vim.log.levels.WARN) end) end
    end,
    on_exit = function() preview.job, preview.url, preview.queue = nil, nil, {} end,
  })
end
vim.api.nvim_create_user_command("MdPreview", md_preview, { desc = "Open this markdown file rendered in Firefox" })

local group = vim.api.nvim_create_augroup("markdown_render", { clear = true })
-- todo.nvim starts treesitter in its own markdown.todo buffers
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "markdown",
  callback = function(ev) pcall(vim.treesitter.start, ev.buf, "markdown") end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "markdown.*" },
  callback = function(ev)
    vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown buf_toggle<cr>", { buffer = ev.buf, desc = "markdown: toggle rendering" })
    vim.keymap.set("n", "<leader>mp", md_preview, { buffer = ev.buf, desc = "markdown: preview in Firefox" })
  end,
})
