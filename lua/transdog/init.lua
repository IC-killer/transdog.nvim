local M = {}

-- 功能1：sdcv 查词
function M.translate_word()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end

	local handle = io.popen("sdcv -n " .. word)
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

	local width = math.min(80, vim.o.columns - 10)
	local height = math.min(20, #lines)

	vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
end

-- 功能2：Ollama AI 翻译
function M.translate_with_ollama()
	vim.cmd('normal! "vy')
	local text = vim.fn.getreg("v")
	if text == "" then
		return
	end

	vim.notify("AI 正在翻译...", vim.log.levels.INFO)

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. No explanation. No thinking process. Text: "
		.. text

	vim.system({ "ollama", "run", "translategemma:4b", prompt }, { text = true }, function(obj)
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

			local width = math.min(70, vim.o.columns - 10)
			local height = math.min(15, #out_lines)

			vim.api.nvim_open_win(out_buf, true, {
				relative = "editor",
				row = (vim.o.lines - height) / 2,
				col = (vim.o.columns - width) / 2,
				width = width,
				height = height,
				border = "rounded",
				title = " AI 离线翻译 ",
			})

			vim.api.nvim_buf_set_keymap(out_buf, "n", "q", ":q<CR>", { noremap = true, silent = true })
		end)
	end)
end

return M
