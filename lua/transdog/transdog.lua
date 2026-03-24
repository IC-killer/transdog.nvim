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

local function use_http()
	return require("transdog.config").options.ollama_host ~= nil
end

local function get_url(path)
	local host = require("transdog.config").options.ollama_host
	return host:gsub("/$", "") .. path
end

local function make_prompt(text)
	return "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text
end

-- Ollama 非流式翻译（异步）
function M.ollama(text, callback)
	local cfg = require("transdog.config").options

	local prompt = "Translate the following text to Chinese. Output ONLY the translation. "
		.. "No explanation. No thinking process. Text: "
		.. text

	if use_http() then
		-- HTTP API 非流式
		local body = vim.json.encode({
			model = cfg.ollama_model,
			prompt = make_prompt(text),
			stream = false,
		})

		vim.system({
			"curl",
			"-s",
			"--max-time",
			"60",
			"-X",
			"POST",
			get_url("/api/generate"),
			"-H",
			"Content-Type: application/json",
			"-d",
			body,
		}, {}, function(obj)
			if obj.code ~= 0 then
				callback(
					nil,
					string.format(
						"curl 错误 (exit %d): %s | stdout: %s",
						obj.code,
						obj.stderr or "",
						obj.stdout or ""
					)
				)
				return
			end
			local ok, data = pcall(vim.json.decode, obj.stdout)
			if not ok or not data or not data.response then
				callback(nil, "解析响应失败: " .. (obj.stdout or ""))
				return
			end
			local clean = data.response:gsub("<think>.-</think>", "")
			clean = clean:gsub("^%s+", ""):gsub("%s+$", "")
			if clean == "" then
				callback(nil, "AI 未返回有效翻译结果")
				return
			end
			callback(clean, nil)
		end)
	else
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
					think_buf = ""
					break
				end
			else
				local s = think_buf:find("<think>", 1, true)
				if s then
					local before = think_buf:sub(1, s - 1)
					if before ~= "" then
						on_chunk(before)
					end
					think_buf = think_buf:sub(s + 7)
					in_think = true
				else
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

	local function flush_and_done(err_msg)
		if raw_buf ~= "" then
			filter_and_emit(raw_buf)
			raw_buf = ""
		end
		if think_buf ~= "" and not in_think then
			on_chunk(think_buf)
			think_buf = ""
		end
		on_done(err_msg)
	end

	if use_http() then
		-- HTTP 流式：每行是一个 JSON 对象 {"response":"...","done":false}
		local body = vim.json.encode({
			model = cfg.ollama_model,
			prompt = make_prompt(text),
			stream = true,
		})

		vim.system({
			"curl",
			"-s",
			"--no-buffer",
			"--max-time",
			"120",
			"-X",
			"POST",
			get_url("/api/generate"),
			"-H",
			"Content-Type: application/json",
			"-d",
			body,
		}, {
			stdout = function(err, chunk)
				if err or not chunk or chunk == "" then
					return
				end

				raw_buf = raw_buf .. chunk
				local safe_pos = utf8_safe_end(raw_buf)
				if safe_pos <= 0 then
					return
				end

				local safe_text = raw_buf:sub(1, safe_pos)
				raw_buf = raw_buf:sub(safe_pos + 1)

				-- 按行解析 JSON，每行格式: {"model":...,"response":"字","done":false}
				for line in safe_text:gmatch("[^\n]+") do
					line = line:gsub("^%s+", ""):gsub("%s+$", "")
					if line ~= "" then
						local ok, data = pcall(vim.json.decode, line)
						if ok and data and data.response then
							vim.schedule(function()
								filter_and_emit(data.response)
							end)
						end
					end
				end
			end,
		}, function(obj)
			vim.schedule(function()
				if obj.code ~= 0 then
					flush_and_done(
						string.format(
							"curl 错误 (exit %d): %s | stdout: %s",
							obj.code,
							obj.stderr or "",
							obj.stdout or ""
						)
					)
				else
					flush_and_done(nil)
				end
			end)
		end)
	else
		-- 本地命令流式（原逻辑不变）
		vim.system({ cfg.ollama_cmd, "run", cfg.ollama_model, make_prompt(text) }, {
			stdout = function(err, chunk)
				if err or not chunk or chunk == "" then
					return
				end
				raw_buf = raw_buf .. chunk
				local safe_pos = utf8_safe_end(raw_buf)
				if safe_pos <= 0 then
					return
				end
				local safe_text = raw_buf:sub(1, safe_pos)
				raw_buf = raw_buf:sub(safe_pos + 1)
				vim.schedule(function()
					filter_and_emit(safe_text)
				end)
			end,
		}, function(obj)
			vim.schedule(function()
				if obj.code ~= 0 then
					flush_and_done("Ollama 错误: " .. (obj.stderr or "未知错误"))
				else
					flush_and_done(nil)
				end
			end)
		end)
	end
end

return M
