local M = {}

-- sdcv 查词（同步）
-- 参数: word string
-- 返回: result string | nil, err string | nil
function M.sdcv(word)
	local cfg = require("transdog.config").options

	local handle = io.popen(cfg.sdcv_cmd .. " -n " .. vim.fn.shellescape(word))
	if not handle then
		return nil, "无法启动 sdcv"
	end

	local result = handle:read("*a")
	handle:close()

	if not result or result == "" then
		return nil, "未找到翻译: " .. word
	end

	return result, nil
end

-- Ollama 翻译（异步）
-- 参数: text string, callback function(result string | nil, err string | nil)
function M.ollama(text, callback)
	local cfg = require("transdog.config").options

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text

	vim.system({ cfg.ollama_cmd, "run", cfg.ollama_model, prompt }, { text = true }, function(obj)
		if obj.code ~= 0 then
			callback(nil, "Ollama 错误: " .. (obj.stderr or "未知错误"))
			return
		end

		-- 清理思考过程和多余空白
		local clean = obj.stdout:gsub("<think>.-</think>", "")
		clean = clean:gsub("^%s+", ""):gsub("%s+$", "")

		if clean == "" then
			callback(nil, "AI 未返回有效翻译结果")
			return
		end

		callback(clean, nil)
	end)
end

return M
