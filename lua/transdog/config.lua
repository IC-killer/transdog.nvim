local M = {}

-- 所有可配置项的默认值
M.defaults = {
	sdcv_cmd = "sdcv", -- sdcv 可执行文件路径
	ollama_model = "translategemma:4b",
	ollama_cmd = "ollama",
	float = {
		border = "rounded",
		max_width = 80,
		max_height = 20,
	},
	keymaps = {
		translate_word = "<leader>tt",
		translate_ollama = "<leader>tt", -- visual 模式
	},
}

-- 运行时实际生效的配置（由 setup 填充）
M.options = {}

function M.setup(opts)
	-- 用用户传入的 opts 覆盖默认值，深合并
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
