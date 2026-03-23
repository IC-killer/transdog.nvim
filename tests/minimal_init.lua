-- 测试时的最小化 Neovim 配置
-- 作用：告诉 Neovim 去哪里找 transdog 和 plenary

-- 1. 把插件根目录加入 runtimepath，让 require("transdog") 能找到
vim.opt.runtimepath:prepend(vim.fn.getcwd())

-- 2. 找到 plenary（从 lazy.nvim 的标准安装路径）
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"

if vim.fn.isdirectory(plenary_path) == 0 then
	-- 如果没装，自动 clone（CI 环境用）
	print("正在安装 plenary.nvim 用于测试...")
	vim.fn.system({
		"git",
		"clone",
		"--depth=1",
		"https://github.com/nvim-lua/plenary.nvim",
		plenary_path,
	})
end

vim.opt.runtimepath:prepend(plenary_path)
