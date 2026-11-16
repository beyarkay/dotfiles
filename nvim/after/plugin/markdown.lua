-- Markdown drawn in place: treesitter highlighting plus render-markdown.nvim.
-- Off the cursor line a link reads as an underlined [text]; the cursor line
-- always shows the raw source.
--   <leader>mr  toggle the rendering in this buffer
--   <leader>mp  :MdPreview, open the file rendered in Firefox (reloads on save)
local ok, rm = pcall(require, "render-markdown")
if not ok then return end

-- Changes to Neovim's markdown_inline query:
--   * keep the brackets of real links, coloured with their text
--   * leave other [bracketed text] and entities like &lt; as typed
--   * draw each * _ ~ marker as a space, so text keeps its column
-- An edit that no longer matches the runtime query is skipped.
local function patch_inline_query()
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
    {
      '%(%[%s*%(code_span_delimiter%)%s*%(emphasis_delimiter%)%s*%]%s*@conceal%s*%(#set! conceal ""%)%)',
      '((code_span_delimiter) @conceal (#set! conceal ""))\n((emphasis_delimiter) @conceal (#set! conceal " "))',
    },
    { '(@character%.special [^\n]*%))%s*%(#set! conceal ".-"%)', "%1" },
  }
  for _, e in ipairs(edits) do
    local patched, n = src:gsub(e[1], e[2])
    if n > 0 then src = patched end
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
patch_inline_query()

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
  hl(0, "@markup.link.label.markdown_inline", { fg = "#61afef", ctermfg = 75 })
  hl(0, "MarkdownLinkUnderline", { underline = true, sp = "#61afef" })
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

-- Underlines for links, and the strike through cancelled `[/]` tasks.
-- With 'linebreak', a wrapped row is padded to the window edge with blanks
-- that copy the highlight of the character it broke at, so a link is
-- underlined only under the characters a line cannot break at.
-- render-markdown would strike a `[/]` task from the `[/]` itself, through
-- the padding and the ☒, so the strike is drawn here from the text instead.
local deco_ns = vim.api.nvim_create_namespace("markdown_decorations")
local link_query = vim.treesitter.query.parse("markdown_inline", [[
  (inline_link ["[" (link_text) "]"] @label)
  (full_reference_link ["[" (link_text) "]"] @label)
  (collapsed_reference_link (link_text) @label)
  (image ["!" "[" (image_description) "]"] @label)
  [(uri_autolink) (email_autolink)] @autolink
]])
local cancelled_query = vim.treesitter.query.parse("markdown", [[
  (list_item (paragraph) @cancelled (#lua-match? @cancelled "^%[/%]%s"))
]])
local deco_rows = {}

-- Spans are { start, end, group }; end -1 runs to the end of the line, and
-- start nil begins at the first non-blank character.
local function add_span(rows, row, s, e, group)
  rows[row] = rows[row] or {}
  table.insert(rows[row], { s, e, group })
end

local function underline_runs(buf, row, line, col, stop)
  local breaks = vim.o.breakat
  while col < stop do
    while col < stop and breaks:find(line:sub(col + 1, col + 1), 1, true) do col = col + 1 end
    local run = col
    while col < stop and not breaks:find(line:sub(col + 1, col + 1), 1, true) do col = col + 1 end
    if col > run then
      vim.api.nvim_buf_set_extmark(buf, deco_ns, row, run, {
        end_col = col, hl_group = "MarkdownLinkUnderline", ephemeral = true,
      })
    end
  end
end

vim.api.nvim_set_decoration_provider(deco_ns, {
  on_win = function(_, _, buf, top, bot)
    if not vim.bo[buf].filetype:match("^markdown") or not vim.treesitter.highlighter.active[buf] then
      return false
    end
    local parser = vim.treesitter.get_parser(buf, "markdown", { error = false })
    if not parser then return false end
    parser:parse({ top, bot + 1 })
    local rows = {}
    local inline = parser:children().markdown_inline
    for _, tree in ipairs(inline and inline:trees() or {}) do
      for id, node in link_query:iter_captures(tree:root(), buf, top, bot + 1) do
        local sr, sc, er, ec = node:range()
        if link_query.captures[id] == "autolink" then sc, ec = sc + 1, ec - 1 end
        for r = math.max(sr, top), math.min(er, bot) do
          add_span(rows, r, r == sr and sc or 0, r == er and ec or -1, "MarkdownLinkUnderline")
        end
      end
    end
    -- todo.nvim strikes its own cancelled tasks
    if vim.bo[buf].filetype == "markdown" then
      for _, tree in ipairs(parser:trees()) do
        for _, node in cancelled_query:iter_captures(tree:root(), buf, top, bot + 1) do
          local sr, sc, er, ec = node:range()
          for r = math.max(sr, top), math.min(er, bot) do
            if not (r == er and ec == 0) then
              add_span(rows, r, r == sr and sc + #"[/] " or nil, r == er and ec or -1, "RenderMarkdownDone")
            end
          end
        end
      end
    end
    deco_rows[buf] = rows
  end,
  on_line = function(_, _, buf, row)
    local spans = deco_rows[buf] and deco_rows[buf][row]
    if not spans then return end
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
    for _, span in ipairs(spans) do
      local s, e, group = span[1], span[2], span[3]
      if e == -1 then e = #line end
      if s == nil then s = (line:find("%S") or #line + 1) - 1 end
      if group == "MarkdownLinkUnderline" then
        underline_runs(buf, row, line, s, e)
      elseif e > s then
        vim.api.nvim_buf_set_extmark(buf, deco_ns, row, s, { end_col = e, hl_group = group, ephemeral = true })
      end
    end
  end,
})

-- render-markdown hides an autolink's < and >; draw them as spaces instead
local has_link_render, link_render = pcall(require, "render-markdown.render.inline.link")
if has_link_render and type(link_render.hide) == "function" then
  function link_render:hide(col, length)
    self.marks:add(self.config, true, self.node.start_row, col, { end_col = col + length, conceal = " " })
  end
end

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
  -- 2, not 3, so markers drawn as a space keep their width
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
      cancelled = { raw = "[/]", rendered = "☒ ", highlight = "RenderMarkdownUnchecked" },
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
