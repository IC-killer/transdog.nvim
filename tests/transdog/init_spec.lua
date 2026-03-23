-- init 模块的测试
local transdog = require("transdog")

describe("transdog.init", function()
	before_each(function()
		-- 每次测试前重置状态
		transdog._setup_called = false
		require("transdog.config").options = {}
	end)

	describe("setup()", function()
		it("调用后 _setup_called 应为 true", function()
			transdog.setup({})

			assert.is_true(transdog._setup_called)
		end)

		it("调用后 config.options 应该被填充", function()
			transdog.setup({ ollama_model = "test-model" })

			local cfg = require("transdog.config").options
			assert.equals("test-model", cfg.ollama_model)
		end)
	end)

	describe("translate_word()", function()
		it("光标下无单词时，不应该报错", function()
			transdog.setup({})
			-- 模拟 expand("<cword>") 返回空字符串
			local orig_expand = vim.fn.expand
			vim.fn.expand = function(expr)
				if expr == "<cword>" then
					return ""
				end
				return orig_expand(expr)
			end

			-- 不应该抛出错误
			assert.has_no.errors(function()
				transdog.translate_word()
			end)

			-- 还原
			vim.fn.expand = orig_expand
		end)
	end)
end)
