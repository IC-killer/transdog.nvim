local M = {}

-- 创建并打开一个浮窗，返回 (buf, win)
-- opts 说明:
--   lines    : string[]  要显示的内容
--   title    : string?   浮窗标题（可选）
--   relative : string    "cursor" | "editor"
local function open_float(lines, opts)
	local cfg = require("transdog.config").options

	local width = math.min(cfg.float.max_width, vim.o.columns - 10)
	local height = math.min(cfg.float.max_height, #lines)

	-- 计算位置
	local row, col
	if opts.relative == "editor" then
		row = math.floor((vim.o.lines - height) / 2)
		col = math.floor((vim.o.columns - width) / 2)
	else
		-- relative = "cursor"
		row, col = 1, 0
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	-- 缓冲区设为只读
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe" -- 关闭窗口时自动删除 buffer

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

	-- 按 q 或 <Esc> 关闭
	local close = function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })

	return buf, win
end

-- 显示 sdcv 查词结果
function M.show_sdcv(result_text)
	local lines = {}
	for line in result_text:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end
	open_float(lines, { relative = "cursor" })
end

-- 显示 Ollama AI 翻译结果
function M.show_ollama(result_text)
	local lines = vim.split(result_text, "\n")
	open_float(lines, { relative = "editor", title = "AI 离线翻译" })
end

return M
