-- Main plugin file for the opengrep-nvim repository.
-- This file is automatically loaded by LazyVim.

-- Create a table to hold our plugin's functions and commands.
local M = {}

-- Defaults
local defaults = {
	cmd = "opengrep",
	cmd_args = {},
	run_on_save = true,
	patterns = {
		"*.lua",
		"*.py",
		"*.sh",
		"*.c",
		"*.cpp",
		"*.js",
		"*.ts",
		"*.html",
		"*.css",
		"*.h",
		"*.hpp",
		"*.c++",
		"*.java",
	},
	notify_on_no_issues = false,
	notify_title = "Opengrep",
	issue_notify_level = vim.log.levels.WARN,
	info_notify_level = vim.log.levels.INFO,
	open_qf_on_results = true,
}

local augroup_id
M.config = vim.deepcopy(defaults)
M.available = true

local function basename(path)
	if vim.fs and vim.fs.basename then
		return vim.fs.basename(path)
	end
	return vim.fn.fnamemodify(path, ":t")
end

local function is_executable(cmd)
	return vim.fn.executable(cmd) == 1
end

-- Async command runner that works across Neovim versions
local function run_cmd(cmd, on_exit)
	-- Prefer vim.system (Neovim 0.10+)
	if vim.system then
		vim.system(cmd, { text = true }, function(obj)
			local code = obj.code or 0
			local stdout = obj.stdout or ""
			local stderr = obj.stderr or ""
			on_exit(code, stdout, stderr)
		end)
		return
	end

	-- Fallback to jobstart
	local out, err = {}, {}
	local ok = vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if not data then
				return
			end
			for _, l in ipairs(data) do
				if l ~= nil then
					table.insert(out, l)
				end
			end
		end,
		on_stderr = function(_, data)
			if not data then
				return
			end
			for _, l in ipairs(data) do
				if l ~= nil then
					table.insert(err, l)
				end
			end
		end,
		on_exit = function(_, code)
			on_exit(code or 0, table.concat(out, "\n"), table.concat(err, "\n"))
		end,
	})

	if ok <= 0 then
		on_exit(1, "", "Failed to start job: " .. table.concat(cmd, " "))
	end
end

local function ensure_available()
	if not is_executable(M.config.cmd) then
		M.available = false
		vim.notify_once(
			("%s not found in PATH. Install it and/or set `require('opengrep').setup{ cmd = '...'}' to the binary path.")
				:format(M.config.cmd),
			vim.log.levels.ERROR,
			{ title = M.config.notify_title }
		)
		return false
	end
	M.available = true
	return true
end

--- Function to run opengrep on the current buffer and display a notification.
M.run_and_notify = function()
	if not ensure_available() then
		return
	end

	-- Get the full path of the current buffer.
	local filename = vim.api.nvim_buf_get_name(0)

	-- If the buffer has no name (e.g., an empty buffer), do nothing.
	if filename == "" then
		return
	end

	-- Create temp SARIF output file
	local sarif_path = vim.fn.tempname() .. ".sarif.json"

	-- Build command: opengrep scan --quiet --sarif-output=<file> <target>
	local cmd = { M.config.cmd, "scan", "--quiet", "--sarif-output=" .. sarif_path }
	for _, a in ipairs(M.config.cmd_args) do
		table.insert(cmd, a)
	end
	table.insert(cmd, filename)

	local function json_decode(str)
		if vim.json and vim.json.decode then
			return pcall(vim.json.decode, str)
		end
		return pcall(vim.fn.json_decode, str)
	end

	local function parse_sarif_findings(sarif_tbl)
		local items = {}
		if type(sarif_tbl) ~= "table" or type(sarif_tbl.runs) ~= "table" then
			return items
		end

		local base_dir_abs
		if filename and filename ~= "" then
			base_dir_abs = vim.fn.fnamemodify(filename, ":h:p")
		elseif directory and directory ~= "" then
			base_dir_abs = vim.fn.fnamemodify(directory, ":p")
		else
			base_dir_abs = vim.fn.getcwd()
		end
		local function is_abs_path(p)
			return type(p) == "string" and (p:match("^/") or p:match("^%a:[/\\]"))
		end
		local function to_path(uri)
			if type(uri) ~= "string" or uri == "" then
				return nil
			end
			if uri:match("^file:") then
				if vim.uri_to_fname then
					local ok, p = pcall(vim.uri_to_fname, uri)
					if ok and p and p ~= "" then
						return p
					end
				end
				uri = uri:gsub("^file://", "")
			end
			if is_abs_path(uri) then
				return uri
			end
			return vim.fn.fnamemodify(base_dir_abs .. "/" .. uri, ":p")
		end

		for _, run in ipairs(sarif_tbl.runs) do
			local results = run.results or {}
			for _, res in ipairs(results) do
				local message = ""
				if type(res.message) == "table" and type(res.message.text) == "string" then
					message = res.message.text
				elseif type(res.message) == "string" then
					message = res.message
				end
				local ruleId = res.ruleId or ""
				local text = ruleId ~= "" and (message .. " [" .. ruleId .. "]") or message
				local locs = res.locations or {}
				for _, loc in ipairs(locs) do
					local pl = loc.physicalLocation or {}
					local art = pl.artifactLocation or {}
					local uri = art.uri or ""
					local region = pl.region or {}
					local lnum = tonumber(region.startLine or region.endLine or 1) or 1
					local col = tonumber(region.startColumn or region.column or 1) or 1
					local fname = to_path(uri)
					if fname and fname ~= "" then
						table.insert(items, { filename = fname, lnum = lnum, col = col, text = text })
					end
				end
			end
		end
		return items
	end

	run_cmd(cmd, function(code, stdout, stderr)
		local err = vim.trim(stderr or "")
		local sarif_content = nil
		local ok_read, lines = pcall(vim.fn.readfile, sarif_path)
		if ok_read and type(lines) == "table" then
			sarif_content = table.concat(lines, "\n")
		end
		pcall(os.remove, sarif_path)

		if not sarif_content or sarif_content == "" then
			if code ~= 0 then
				vim.schedule(function()
					vim.notify(err ~= "" and err or ("Command failed: %s"):format(table.concat(cmd, " ")),
						vim.log.levels.ERROR, { title = M.config.notify_title })
				end)
			else
				if M.config.notify_on_no_issues then
					vim.schedule(function()
						vim.notify(("No issues found in %s"):format(basename(filename)), M.config.info_notify_level,
							{ title = M.config.notify_title })
					end)
				end
			end
			return
		end

		local ok_json, sarif_tbl = json_decode(sarif_content)
		if not ok_json or type(sarif_tbl) ~= "table" then
			vim.schedule(function()
				vim.notify("Failed to parse SARIF output", vim.log.levels.ERROR, { title = M.config.notify_title })
			end)
			return
		end

		local items = parse_sarif_findings(sarif_tbl)
		local count = #items
		if count == 0 then
			if M.config.notify_on_no_issues then
				vim.schedule(function()
					vim.notify(("No issues found in %s"):format(basename(filename)), M.config.info_notify_level,
						{ title = M.config.notify_title })
				end)
			end
			return
		end

		vim.schedule(function()
			local first = items[1]
			local first_txt = first and first.text or ""
			vim.notify(string.format("Found %d issue%s in %s. First: %s", count, count ~= 1 and "s" or "",
				basename(filename), first_txt), M.config.issue_notify_level, { title = M.config.notify_title })
		end)
	end)
end

--- Function to run opengrep and populate the quickfix list for manual review.
--- @param args string[] The arguments passed to the command.
M.run_and_qf = function(args)
	if not ensure_available() then
		return
	end

	local directory = (args and args[1]) or vim.fn.getcwd()
	if directory and directory:sub(1, 1) == "~" then
		directory = vim.fn.expand(directory)
	end

	-- Create temp SARIF output file
	local sarif_path = vim.fn.tempname() .. ".sarif.json"

	-- Build command: opengrep scan --quiet --sarif-output=<file> <dir>
	local cmd = { M.config.cmd, "scan", "--quiet", "--sarif-output=" .. sarif_path }
	for _, a in ipairs(M.config.cmd_args) do
		table.insert(cmd, a)
	end
	table.insert(cmd, directory)

	local function json_decode(str)
		if vim.json and vim.json.decode then
			return pcall(vim.json.decode, str)
		end
		return pcall(vim.fn.json_decode, str)
	end

	local function parse_sarif_findings(sarif_tbl)
		local items = {}
		if type(sarif_tbl) ~= "table" or type(sarif_tbl.runs) ~= "table" then
			return items
		end

		local base_dir_abs
		if filename and filename ~= "" then
			base_dir_abs = vim.fn.fnamemodify(filename, ":h:p")
		elseif directory and directory ~= "" then
			base_dir_abs = vim.fn.fnamemodify(directory, ":p")
		else
			base_dir_abs = vim.fn.getcwd()
		end
		local function is_abs_path(p)
			return type(p) == "string" and (p:match("^/") or p:match("^%a:[/\\]"))
		end
		local function to_path(uri)
			if type(uri) ~= "string" or uri == "" then
				return nil
			end
			if uri:match("^file:") then
				if vim.uri_to_fname then
					local ok, p = pcall(vim.uri_to_fname, uri)
					if ok and p and p ~= "" then
						return p
					end
				end
				uri = uri:gsub("^file://", "")
			end
			if is_abs_path(uri) then
				return uri
			end
			return vim.fn.fnamemodify(base_dir_abs .. "/" .. uri, ":p")
		end

		for _, run in ipairs(sarif_tbl.runs) do
			local results = run.results or {}
			for _, res in ipairs(results) do
				local message = ""
				if type(res.message) == "table" and type(res.message.text) == "string" then
					message = res.message.text
				elseif type(res.message) == "string" then
					message = res.message
				end
				local ruleId = res.ruleId or ""
				local text = ruleId ~= "" and (message .. " [" .. ruleId .. "]") or message
				local locs = res.locations or {}
				for _, loc in ipairs(locs) do
					local pl = loc.physicalLocation or {}
					local art = pl.artifactLocation or {}
					local uri = art.uri or ""
					local region = pl.region or {}
					local lnum = tonumber(region.startLine or region.endLine or 1) or 1
					local col = tonumber(region.startColumn or region.column or 1) or 1
					local fname = to_path(uri)
					if fname and fname ~= "" then
						table.insert(items, { filename = fname, lnum = lnum, col = col, text = text })
					end
				end
			end
		end
		return items
	end

	run_cmd(cmd, function(code, stdout, stderr)
		local err = vim.trim(stderr or "")
		local sarif_content = nil
		local ok_read, lines = pcall(vim.fn.readfile, sarif_path)
		if ok_read and type(lines) == "table" then
			sarif_content = table.concat(lines, "\n")
		end
		pcall(os.remove, sarif_path)

		if code ~= 0 and (not sarif_content or sarif_content == "") then
			vim.notify(err ~= "" and err or ("Command failed: %s"):format(table.concat(cmd, " ")), vim.log.levels.ERROR, { title = M.config.notify_title })
			return
		end

		local ok_json, sarif_tbl = json_decode(sarif_content or "{}")
		if not ok_json or type(sarif_tbl) ~= "table" then
			vim.notify("Failed to parse SARIF output", vim.log.levels.ERROR, { title = M.config.notify_title })
			return
		end

		local qf_list = parse_sarif_findings(sarif_tbl)
		local title = string.format('Opengrep: scan in %s', directory)
		vim.schedule(function()
			vim.fn.setqflist({}, 'r', { title = title, items = qf_list })
			if #qf_list > 0 then
				local info = vim.fn.getqflist({ winid = 0 })
				local is_open = info and info.winid and info.winid ~= 0
				if M.config.open_qf_on_results and not is_open then
					vim.cmd("copen")
				end
				vim.notify(#qf_list .. " findings added to quickfix.", M.config.info_notify_level, { title = M.config.notify_title })
			else
				vim.notify("No findings.", M.config.info_notify_level, { title = M.config.notify_title })
			end
		end)
	end)
end

-- Setup with configuration and autocmds
--- @param opts table|nil
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", defaults, opts or {})
	configured = true

	-- Augroup: clear existing to avoid duplicates
	augroup_id = vim.api.nvim_create_augroup("OpengrepGroup", { clear = true })

	if M.config.run_on_save and ensure_available() then
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = augroup_id,
			pattern = M.config.patterns,
			callback = function()
				M.run_and_notify()
			end,
		})
	end

	-- Refresh user command to use our latest config
	pcall(vim.api.nvim_del_user_command, "OGrep")
	vim.api.nvim_create_user_command("OGrep", function(opts_)
		M.run_and_qf(opts_.fargs)
	end, { nargs = "?", complete = "dir" })

	-- Back-compat alias for old command name
	pcall(vim.api.nvim_del_user_command, "OpengrepQf")
	vim.api.nvim_create_user_command("OpengrepQf", function(opts_)
		vim.schedule(function()
			vim.notify("Deprecated: use :OGrep instead of :OpengrepQf", M.config.info_notify_level, { title = M.config.notify_title })
		end)
		M.run_and_qf(opts_.fargs)
	end, { nargs = "?", complete = "dir" })
end

-- Back-compat: initialize with defaults so it works out-of-the-box
-- Users can call setup{} later to override; setup clears/refreshes autocmds/commands.
M.setup()

return M
