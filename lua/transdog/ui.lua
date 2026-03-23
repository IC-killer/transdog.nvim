local M = {}

-- ── 状态栏 ──────────────────────────────────────────────────────────────────

M._status = ""
local status_timer = nil

local function set_status(icon, msg, auto_clear)
	M._status = icon .. " " .. msg
	if package.loaded["lualine"] then
		require("lualine").refresh()
	end
	if auto_clear then
		if status_timer then
			status_timer:stop()
		end
		status_timer = vim.defer_fn(function()
			M._status = ""
			if package.loaded["lualine"] then
				require("lualine").refresh()
			end
		end, 5000)
	end
end

function M.status_running()
	set_status("🐕", "翻译中...")
end
function M.status_done()
	set_status("✅", "翻译完成", true)
end
function M.status_error(msg)
	set_status("❌", msg or "翻译失败", true)
end
function M.status_clear()
	M._status = ""
end

-- ── 折行工具 ─────────────────────────────────────────────────────────────────

-- 按【显示宽度】折行，正确处理中文等宽字符
-- 中文字符显示宽度为 2，英文为 1
local function wrap_line(line, wrap_width)
	if vim.fn.strdisplaywidth(line) <= wrap_width then
		return { line }
	end

	local result = {}
	local current = ""
	local cur_w = 0

	-- 按 UTF-8 字符逐个遍历
	for _, codepoint in utf8.codes(line) do
		local char = utf8.char(codepoint)
		local char_w = vim.fn.strdisplaywidth(char)

		if cur_w + char_w > wrap_width then
			-- 当前行放不下，换行
			if current ~= "" then
				table.insert(result, current)
			end
			current = char
			cur_w = char_w
		else
			current = current .. char
			cur_w = cur_w + char_w
		end
	end

	if current ~= "" then
		table.insert(result, current)
	end

	return result
end

local function wrap_lines(lines, wrap_width)
	local wrapped = {}
	for _, line in ipairs(lines) do
		if line == "" then
			table.insert(wrapped, "")
		else
			for _, wl in ipairs(wrap_line(line, wrap_width)) do
				table.insert(wrapped, wl)
			end
		end
	end
	return wrapped
end

-- ── 浮窗核心（静态，内容一次性写入）────────────────────────────────────────

local function open_float(lines, opts)
	local cfg = require("transdog.config").options

	local wrapped = wrap_lines(lines, cfg.float.wrap_width)

	local content_width = 0
	for _, l in ipairs(wrapped) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(l))
	end
	local width = math.min(math.max(content_width + 2, 40), cfg.float.max_width)
	local height = math.min(cfg.float.max_height, #wrapped)

	local row, col
	if opts.relative == "editor" then
		row = math.floor((vim.o.lines - height) / 2)
		col = math.floor((vim.o.columns - width) / 2)
	else
		row, col = 1, 0
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, wrapped)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local win_opts = {
		relative = opts.relative,
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = cfg.float.border,
	}
	if opts.title then
		win_opts.title = " " .. opts.title .. " "
		win_opts.title_pos = "center"
	end

	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })

	return buf, win
end

-- ── 流式浮窗（内容动态追加）─────────────────────────────────────────────────

function M.open_stream_float(title)
	local cfg = require("transdog.config").options
	-- 打开时就用最终最大尺寸，后续不再改变窗口大小
	local width = math.min(cfg.float.max_width, vim.o.columns - 4)
	local height = math.min(cfg.float.max_height, math.floor(vim.o.lines * 0.6))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = cfg.float.border,
		title = " " .. title .. " ",
		title_pos = "center",
	})

	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })

	return buf, win
end

function M.stream_append(buf, win, new_text)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local cfg = require("transdog.config").options

	-- 取出现有内容，拼上新 chunk，重新折行写回
	local current = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- 最后一行可能是上次折行留下的半行，直接和新 chunk 拼接
	local last = table.remove(current) or ""
	local combined = last .. new_text
	local new_lines = vim.split(combined, "\n", { plain = true })
	local wrapped_new = wrap_lines(new_lines, cfg.float.wrap_width)

	-- 合并：原来的行 + 新折行的内容
	local all = {}
	for _, l in ipairs(current) do
		table.insert(all, l)
	end
	for _, l in ipairs(wrapped_new) do
		table.insert(all, l)
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, all)
	vim.bo[buf].modifiable = false

	-- 滚动到最后一行，窗口大小保持不变（open_stream_float 已固定）
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, { #all, 0 })
	end
end

-- ── 对外接口 ──────────────────────────────────────────────────────────────────

function M.show_sdcv(result_text)
	local lines = {}
	for line in result_text:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	open_float(lines, { relative = "cursor" })
end

function M.show_ollama(result_text)
	local lines = vim.split(result_text, "\n", { plain = true })
	open_float(lines, { relative = "editor", title = "🐕 Transdog AI 翻译" })
end

return M
