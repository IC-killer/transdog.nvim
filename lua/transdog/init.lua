local M = {}

function M.setup(opts)
	require("transdog.config").setup(opts)
	M._setup_called = true -- 标记已调用
end

function M.translate_word()
	local cfg = require("transdog.config").options
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end

	-- 使用配置中的命令，而不是硬编码 "sdcv"
	local handle = io.popen(cfg.sdcv_cmd .. " -n " .. word)
	local result = handle:read("*a")
	handle:close()

	if result == "" or result == nil then
		print("未找到翻译: " .. word)
		return
	end

	local lines = {}
	for line in result:gmatch("[^\r\n]+") do
		table.insert(lines, line)
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = math.min(cfg.float.max_width, vim.o.columns - 10)
	local height = math.min(cfg.float.max_height, #lines)

	vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = cfg.float.border,
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

function M.translate_with_ollama()
	local cfg = require("transdog.config").options

	vim.cmd('normal! "vy')
	local text = vim.fn.getreg("v")
	if text == "" then
		return
	end

	vim.notify("AI 正在翻译...", vim.log.levels.INFO)

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text

	-- 使用配置中的命令和模型名
	vim.system({ cfg.ollama_cmd, "run", cfg.ollama_model, prompt }, { text = true }, function(obj)
		vim.schedule(function()
			if obj.code ~= 0 then
				vim.notify("Ollama 错误: " .. (obj.stderr or ""), vim.log.levels.ERROR)
				return
			end

			local clean_text = obj.stdout:gsub("<think>.-</think>", "")
			clean_text = clean_text:gsub("^%s*", ""):gsub("%s*$", "")
			if clean_text == "" then
				clean_text = "AI 未返回有效翻译结果。"
			end

			local out_buf = vim.api.nvim_create_buf(false, true)
			local out_lines = vim.split(clean_text, "\n")
			vim.api.nvim_buf_set_lines(out_buf, 0, -1, false, out_lines)

			local width = math.min(cfg.float.max_width, vim.o.columns - 10)
			local height = math.min(cfg.float.max_height, #out_lines)

			vim.api.nvim_open_win(out_buf, true, {
				relative = "editor",
				row = (vim.o.lines - height) / 2,
				col = (vim.o.columns - width) / 2,
				width = width,
				height = height,
				border = cfg.float.border,
				title = " AI 离线翻译 ",
			})

			vim.api.nvim_buf_set_keymap(out_buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
		end)
	end)
end

return M
