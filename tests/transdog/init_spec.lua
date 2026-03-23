-- init 模块的测试
local transdog = require("transdog")

describe("transdog.init", function()
	before_each(function()
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

		it("stream 配置应传递到 config", function()
			transdog.setup({ stream = false })

			local cfg = require("transdog.config").options
			assert.is_false(cfg.stream)
		end)

		it("重复调用 setup() 不应该报错", function()
			assert.has_no.errors(function()
				transdog.setup({})
				transdog.setup({ ollama_model = "second" })
			end)
		end)
	end)

	describe("translate_word()", function()
		it("光标下无单词时，不应该报错", function()
			transdog.setup({})

			local orig_expand = vim.fn.expand
			vim.fn.expand = function(expr)
				if expr == "<cword>" then
					return ""
				end
				return orig_expand(expr)
			end

			assert.has_no.errors(function()
				transdog.translate_word()
			end)

			vim.fn.expand = orig_expand
		end)
	end)

	describe("translate_with_ollama()", function()
		it("寄存器内容为空时，不应该报错", function()
			transdog.setup({})

			-- 模拟 v 寄存器为空
			local orig_getreg = vim.fn.getreg
			vim.fn.getreg = function(reg)
				if reg == "v" then
					return ""
				end
				return orig_getreg(reg)
			end

			assert.has_no.errors(function()
				transdog.translate_with_ollama()
			end)

			vim.fn.getreg = orig_getreg
		end)
	end)

	describe("lualine_status()", function()
		it("初始状态应返回空字符串", function()
			transdog.setup({})

			-- 重置 ui 状态
			require("transdog.ui")._status = ""

			assert.equals("", transdog.lualine_status())
		end)

		it("状态变化后应正确反映", function()
			transdog.setup({})

			require("transdog.ui").status_running()
			local status = transdog.lualine_status()

			assert.is_not_nil(status)
			assert.is_true(#status > 0)
		end)
	end)
end)
