-- config 模块的测试
local config = require("transdog.config")

describe("transdog.config", function()
	before_each(function()
		config.options = {}
	end)

	describe("默认值", function()
		it("setup() 不传参数，应该加载所有默认值", function()
			config.setup()

			assert.equals("sdcv", config.options.sdcv_cmd)
			assert.equals("ollama", config.options.ollama_cmd)
			assert.equals("translategemma:4b", config.options.ollama_model)
		end)

		it("float 默认值应正确", function()
			config.setup()

			assert.equals("rounded", config.options.float.border)
			assert.equals(120, config.options.float.max_width)
			assert.equals(40, config.options.float.max_height)
			assert.equals(100, config.options.float.wrap_width)
		end)

		it("stream 默认值应为 true", function()
			config.setup()

			assert.is_true(config.options.stream)
		end)

		it("keymaps 默认值应该存在", function()
			config.setup()

			assert.is_not_nil(config.options.keymaps.translate_word)
			assert.is_not_nil(config.options.keymaps.translate_ollama)
		end)
	end)

	describe("覆盖默认值", function()
		it("传入 ollama_model，应该覆盖默认模型名", function()
			config.setup({ ollama_model = "qwen2.5:3b" })

			assert.equals("qwen2.5:3b", config.options.ollama_model)
		end)

		it("stream = false 应该生效", function()
			config.setup({ stream = false })

			assert.is_false(config.options.stream)
		end)

		it("传入部分 float 配置，未传的字段应保留默认值", function()
			config.setup({ float = { border = "single" } })

			assert.equals("single", config.options.float.border)
			assert.equals(120, config.options.float.max_width) -- 未传，保留默认
			assert.equals(100, config.options.float.wrap_width) -- 未传，保留默认
		end)

		it("传入完整 float 配置，所有字段都应被覆盖", function()
			config.setup({
				float = { border = "none", max_width = 60, max_height = 20, wrap_width = 50 },
			})

			assert.equals("none", config.options.float.border)
			assert.equals(60, config.options.float.max_width)
			assert.equals(20, config.options.float.max_height)
			assert.equals(50, config.options.float.wrap_width)
		end)

		it("传入自定义 keymaps，应该覆盖默认值，未传的保留默认", function()
			config.setup({ keymaps = { translate_word = "<leader>tw" } })

			assert.equals("<leader>tw", config.options.keymaps.translate_word)
			assert.is_not_nil(config.options.keymaps.translate_ollama) -- 未传，保留默认
		end)
	end)

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

		it("多次调用 setup()，未覆盖的字段应保留默认值", function()
			config.setup({ ollama_model = "my-model" })

			assert.is_true(config.options.stream) -- 未传，保留默认 true
			assert.equals("sdcv", config.options.sdcv_cmd) -- 未传，保留默认
		end)
	end)
end)
