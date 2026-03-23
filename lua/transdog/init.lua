local M = {}

function M.setup(opts)
	require("transdog.config").setup(opts)
	require("transdog.commands").setup()
	M._setup_called = true
end

function M.translate_word()
	local ui = require("transdog.ui")
	local word = vim.fn.expand("<cword>")
	if word == "" then
		return
	end

	local result, err = require("transdog.transdog").sdcv(word)
	if err then
		vim.notify(err, vim.log.levels.WARN)
		return
	end

	ui.show_sdcv(result)
end

function M.translate_with_ollama()
	local cfg = require("transdog.config").options
	local ui = require("transdog.ui")

	vim.cmd('normal! "vy')
	local text = vim.fn.getreg("v")
	if text == "" then
		return
	end

	ui.status_running()

	if cfg.stream then
		-- ── 流式模式 ──────────────────────────────────────────
		local buf, win = ui.open_stream_float("🐕 Transdog AI 翻译")

		require("transdog.transdog").ollama_stream(text, function(chunk)
			-- 每个 chunk 追加到浮窗
			ui.stream_append(buf, win, chunk)
		end, function(err)
			if err then
				ui.status_error(err)
				vim.notify(err, vim.log.levels.ERROR)
			else
				ui.status_done()
			end
		end)
	else
		-- ── 非流式模式 ────────────────────────────────────────
		vim.notify("AI 正在翻译...", vim.log.levels.INFO)

		require("transdog.transdog").ollama(text, function(result, err)
			vim.schedule(function()
				if err then
					ui.status_error(err)
					vim.notify(err, vim.log.levels.ERROR)
					return
				end
				ui.status_done()
				ui.show_ollama(result)
			end)
		end)
	end
end

-- 给 lualine 调用的状态函数
function M.lualine_status()
	return require("transdog.ui")._status
end

return M
