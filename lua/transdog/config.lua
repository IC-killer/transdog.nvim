local M = {}

M.defaults = {
	sdcv_cmd = "sdcv",
	ollama_cmd = "ollama",
	ollama_model = "translategemma:4b",
	ollama_host = nil, -- nil 表示用本地命令，设置后走 HTTP API
	--   例如 "http://192.168.1.100:11434"
	stream = true,
	float = {
		border = "rounded",
		max_width = 120,
		max_height = 40,
		wrap_width = 100,
	},
	keymaps = {
		translate_word = "<leader>tt",
		translate_ollama = "<leader>tt",
	},
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
