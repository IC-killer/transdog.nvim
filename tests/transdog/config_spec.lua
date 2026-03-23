-- config 模块的测试
-- "_spec.lua" 是 plenary 识别测试文件的约定命名

local config = require("transdog.config")

-- describe：测试分组
describe("transdog.config", function()
	-- 每个 it() 跑之前重置 options，避免用例互相污染
	before_each(function()
		config.options = {}
	end)

	-- 测试默认值
	describe("默认值", function()
		it("setup() 不传参数，应该加载所有默认值", function()
			config.setup()

			assert.equals("sdcv", config.options.sdcv_cmd)
			assert.equals("ollama", config.options.ollama_cmd)
			assert.equals("translategemma:4b", config.options.ollama_model)
			assert.equals("rounded", config.options.float.border)
			assert.equals(80, config.options.float.max_width)
			assert.equals(20, config.options.float.max_height)
		end)

		it("keymaps 默认值应该存在", function()
			config.setup()

			assert.is_not_nil(config.options.keymaps.translate_word)
			assert.is_not_nil(config.options.keymaps.translate_ollama)
		end)
	end)

	-- 测试用户传入的配置能正确覆盖默认值
	describe("覆盖默认值", function()
		it("传入 ollama_model，应该覆盖默认模型名", function()
			config.setup({ ollama_model = "qwen2.5:3b" })

			assert.equals("qwen2.5:3b", config.options.ollama_model)
		end)

		it("传入部分 float 配置，未传的字段应保留默认值", function()
			config.setup({ float = { border = "single" } })

			assert.equals("single", config.options.float.border)
			-- max_width 没传，应保留默认的 80
			assert.equals(80, config.options.float.max_width)
		end)

		it("传入完整 float 配置，所有字段都应被覆盖", function()
			config.setup({
				float = { border = "none", max_width = 40, max_height = 10 },
			})

			assert.equals("none", config.options.float.border)
			assert.equals(40, config.options.float.max_width)
			assert.equals(10, config.options.float.max_height)
		end)
	end)

	-- 测试边界情况
	describe("边界情况", function()
		it("传入 nil，等同于不传参数", function()
			config.setup(nil)

			assert.equals("sdcv", config.options.sdcv_cmd)
		end)

		it("多次调用 setup()，后一次完全覆盖前一次", function()
			config.setup({ ollama_model = "first-model" })
			config.setup({ ollama_model = "second-model" })

			assert.equals("second-model", config.options.ollama_model)
		end)
	end)
end)
