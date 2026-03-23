-- 防止重复加载
if vim.g.loaded_translate_nvim then
	return
end
vim.g.loaded_translate_nvim = true

local t = require("transdog")

vim.keymap.set("n", "<leader>tt", t.translate_word, { desc = "极简离线翻译 (sdcv)" })
vim.keymap.set("v", "<leader>tt", t.translate_with_ollama, { desc = "AI 翻译 (Ollama)" })
