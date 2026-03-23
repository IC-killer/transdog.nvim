if vim.g.loaded_translate_nvim then
	return
end
vim.g.loaded_translate_nvim = true

-- 用默认配置初始化（用户没有调用 setup() 时也能正常工作）
local ok, translate = pcall(require, "transdog")
if not ok then
	return
end

if not translate._setup_called then
	translate.setup({})
end

local cfg = require("transdog.config").options

vim.keymap.set("n", cfg.keymaps.translate_word, translate.translate_word, { desc = "离线翻译 (sdcv)" })
vim.keymap.set("v", cfg.keymaps.translate_ollama, translate.translate_with_ollama, { desc = "AI 翻译 (Ollama)" })
