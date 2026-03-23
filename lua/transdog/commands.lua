local M = {}

function M.setup()
	local t = require("transdog")

	-- :Transdog
	-- 普通模式：翻译光标下的词
	-- 可视模式：翻译选中内容（通过 range 判断）
	vim.api.nvim_create_user_command("Transdog", function(args)
		if args.range > 0 then
			t.translate_with_ollama()
		else
			t.translate_word()
		end
	end, {
		range = true,
		desc = "翻译：普通模式查词(sdcv)，可视模式 AI 翻译(Ollama)",
	})

	-- :TransdogWord  强制用 sdcv 查词（不管模式）
	vim.api.nvim_create_user_command("TransdogWord", function()
		t.translate_word()
	end, {
		desc = "sdcv 查词翻译",
	})

	-- :TransdogAI  强制用 Ollama（不管模式）
	vim.api.nvim_create_user_command("TransdogAI", function()
		t.translate_with_ollama()
	end, {
		desc = "Ollama AI 翻译",
	})
end

return M
