local M = {}

-- sdcv 查词（同步）
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

-- Ollama 非流式翻译（异步）
function M.ollama(text, callback)
	local cfg = require("transdog.config").options

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text

	-- 不用 text=true，直接拿原始字节，避免平台做任何编码转换
	vim.system({ cfg.ollama_cmd, "run", cfg.ollama_model, prompt }, {}, function(obj)
		if obj.code ~= 0 then
			callback(nil, "Ollama 错误: " .. (obj.stderr or "未知错误"))
			return
		end
		local clean = obj.stdout:gsub("<think>.-</think>", "")
		clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
		if clean == "" then
			callback(nil, "AI 未返回有效翻译结果")
			return
		end
		callback(clean, nil)
	end)
end

-- ── UTF-8 工具 ───────────────────────────────────────────────────────────────

-- 判断一个字节是否是 UTF-8 多字节序列的起始字节
local function is_utf8_start(byte)
	-- 0x00-0x7F: ASCII 单字节
	-- 0xC0-0xFF: 多字节起始
	-- 0x80-0xBF: 续字节（不是起始）
	return byte < 0x80 or byte >= 0xC0
end

-- 从字符串末尾找到最后一个完整 UTF-8 字符的结束位置
-- 返回 (safe_end_pos) : s:sub(1, safe_end_pos) 保证是合法 UTF-8
local function utf8_safe_end(s)
	local len = #s
	if len == 0 then
		return 0
	end

	-- 从末尾往前找，最多找 3 个续字节（UTF-8 最长 4 字节）
	for back = 0, math.min(3, len - 1) do
		local pos = len - back
		local byte = s:byte(pos)
		if is_utf8_start(byte) then
			-- 计算这个字符应该有多少字节
			local char_len
			if byte < 0x80 then
				char_len = 1 -- ASCII
			elseif byte < 0xE0 then
				char_len = 2
			elseif byte < 0xF0 then
				char_len = 3
			else
				char_len = 4
			end
			-- 检查从 pos 开始是否有足够的字节
			if pos + char_len - 1 <= len then
				-- 这个字符是完整的，整个字符串到 len 都安全
				return len
			else
				-- 这个字符不完整，安全边界在 pos-1
				return pos - 1
			end
		end
	end
	-- 都是续字节，往前再找一个起始字节
	for back = 4, len - 1 do
		local pos = len - back
		local byte = s:byte(pos)
		if is_utf8_start(byte) then
			return pos - 1
		end
	end
	return 0
end

-- ── 流式翻译 ─────────────────────────────────────────────────────────────────

function M.ollama_stream(text, on_chunk, on_done)
	local cfg = require("transdog.config").options

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text

	-- raw_buf   : 字节层缓冲，用于拼接不完整的 UTF-8 字符
	-- think_buf : 文本层缓冲，用于跨 chunk 过滤 <think> 块
	local raw_buf = ""
	local think_buf = ""
	local in_think = false

	local function filter_and_emit(safe_text)
		think_buf = think_buf .. safe_text

		while true do
			if in_think then
				local e = think_buf:find("</think>", 1, true)
				if e then
					think_buf = think_buf:sub(e + 8)
					in_think = false
				else
					-- 还在 think 块里，全部丢弃等结束标记
					think_buf = ""
					break
				end
			else
				local s = think_buf:find("<think>", 1, true)
				if s then
					-- <think> 之前的内容是正常翻译，输出
					local before = think_buf:sub(1, s - 1)
					if before ~= "" then
						on_chunk(before)
					end
					think_buf = think_buf:sub(s + 7)
					in_think = true
				else
					-- 没有 <think>，但末尾可能是 "<think>" 的残缺前缀
					-- "<think>" 最长 7 字节，保守保留末尾 7 字节
					local guard = 7
					if #think_buf > guard then
						on_chunk(think_buf:sub(1, #think_buf - guard))
						think_buf = think_buf:sub(#think_buf - guard + 1)
					end
					break
				end
			end
		end
	end

	-- 不使用 text=true，完全按原始字节接收，自己处理 UTF-8
	vim.system({ cfg.ollama_cmd, "run", cfg.ollama_model, prompt }, {
		stdout = function(err, chunk)
			if err or not chunk or chunk == "" then
				return
			end

			-- 字节层：把新 chunk 追加到 raw_buf，找安全截断点
			raw_buf = raw_buf .. chunk
			local safe_pos = utf8_safe_end(raw_buf)

			if safe_pos > 0 then
				local safe_text = raw_buf:sub(1, safe_pos)
				raw_buf = raw_buf:sub(safe_pos + 1)
				vim.schedule(function()
					filter_and_emit(safe_text)
				end)
			end
			-- safe_pos == 0 说明整个 raw_buf 都是残缺字节，等下一个 chunk
		end,
	}, function(obj)
		vim.schedule(function()
			-- flush raw_buf（结束时强制输出剩余内容）
			if raw_buf ~= "" then
				filter_and_emit(raw_buf)
				raw_buf = ""
			end
			-- flush think_buf（结束时输出不在 think 块里的剩余内容）
			if think_buf ~= "" and not in_think then
				on_chunk(think_buf)
				think_buf = ""
			end

			if obj.code ~= 0 then
				on_done("Ollama 错误: " .. (obj.stderr or "未知错误"))
			else
				on_done(nil)
			end
		end)
	end)
end

return M
