local M = {}

function M.setup(opts)
	require("transdog.config").setup(opts)
	require("transdog.commands").setup()
	M._setup_called = true
end

function M.translate_word()
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end

	local result, err = require("transdog.transdog").sdcv(word)
	if err then
		vim.notify(err, vim.log.levels.WARN)
		return
	end

	require("transdog.ui").show_sdcv(result)
end

function M.translate_with_ollama()
	vim.cmd('normal! "vy')
	local text = vim.fn.getreg("v")
	if text == "" then
		return
	end

	vim.notify("AI 正在翻译...", vim.log.levels.INFO)

	require("transdog.transdog").ollama(text, function(result, err)
		vim.schedule(function()
			if err then
				vim.notify(err, vim.log.levels.ERROR)
				return
			end
			require("transdog.ui").show_ollama(result)
		end)
	end)
end

return M
