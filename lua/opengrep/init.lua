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

	-- Build command
	local cmd = { M.config.cmd }
	for _, a in ipairs(M.config.cmd_args) do
		table.insert(cmd, a)
	end
	table.insert(cmd, filename)

	run_cmd(cmd, function(code, stdout, stderr)
		local out = vim.trim(stdout or "")
		local err = vim.trim(stderr or "")

		if code ~= 0 and out == "" then
			local msg = err ~= "" and err or ("Command failed: %s"):format(table.concat(cmd, " "))
			vim.schedule(function()
				vim.notify(msg, vim.log.levels.ERROR, { title = M.config.notify_title })
			end)
			return
		end

		if out == "" then
			if M.config.notify_on_no_issues then
				vim.schedule(function()
					vim.notify(
						("No issues found in %s"):format(basename(filename)),
						M.config.info_notify_level,
						{ title = M.config.notify_title }
					)
				end)
			end
			return
		end

		local lines = vim.split(out, "\n", { trimempty = true })
		local issue_count = #lines
		local first_line = lines[1] or ""

		vim.schedule(function()
			vim.notify(
				string.format(
					"Found %d issue%s in %s. First: %s",
					issue_count,
					issue_count ~= 1 and "s" or "",
					basename(filename),
					first_line
				),
				M.config.issue_notify_level,
				{ title = M.config.notify_title }
			)
		end)
	end)
end

--- Function to run opengrep and populate the quickfix list for manual review.
--- @param args string[] The arguments passed to the command.
M.run_and_qf = function(args)
	if not ensure_available() then
		return
	end

	local pattern = args and args[1] or nil
	local directory = (args and args[2]) or vim.fn.getcwd()
	-- Expand ~ in directory if present
	if directory and directory:sub(1, 1) == "~" then
		directory = vim.fn.expand(directory)
	end

	if not pattern or pattern == "" then
		vim.notify("Usage: :OGrep {pattern} [directory]", M.config.info_notify_level, { title = M.config.notify_title })
		return
	end

	local cmd = { M.config.cmd }
	for _, a in ipairs(M.config.cmd_args) do
		table.insert(cmd, a)
	end
	table.insert(cmd, pattern)
	table.insert(cmd, directory)

	run_cmd(cmd, function(code, stdout, stderr)
		local out = vim.trim(stdout or "")
		local err = vim.trim(stderr or "")

		if code ~= 0 and out == "" then
			local msg = err ~= "" and err or ("Command failed: %s"):format(table.concat(cmd, " "))
			vim.notify(msg, vim.log.levels.ERROR, { title = M.config.notify_title })
			return
		end

		local lines = vim.split(out, "\n", { trimempty = true })
		local qf_list = {}

		for _, line in ipairs(lines) do
			if line ~= "" then
				-- Try to parse lines like: /path/file:lnum:col:text (filename may contain colons on Windows)
				local fname, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
				if fname and lnum and col then
					table.insert(qf_list, {
						filename = fname,
						lnum = tonumber(lnum),
						col = tonumber(col) or 1,
						text = text or "",
					})
				else
					local parts = vim.split(line, ":", { plain = true })
					if #parts >= 3 then
						local filename2 = parts[1]
						local lnum2 = tonumber(parts[2])
						local col2 = tonumber(parts[3]) or 1
						local text2 = table.concat(parts, ":", 4)
						if filename2 and lnum2 then
							table.insert(qf_list, {
								filename = filename2,
								lnum = lnum2,
								col = col2,
								text = text2,
							})
						end
					end
				end
			end
		end

		local title = string.format('Opengrep: "%s" in %s', pattern, directory)
		vim.schedule(function()
			vim.fn.setqflist({}, 'r', { title = title, items = qf_list })
			if #qf_list > 0 then
				local info = vim.fn.getqflist({ winid = 0 })
				local is_open = info and info.winid and info.winid ~= 0
				if M.config.open_qf_on_results and not is_open then
					vim.cmd("copen")
				end
				vim.notify(#qf_list .. " matches found in quickfix list.", M.config.info_notify_level, { title = M.config.notify_title })
			else
				vim.notify("No matches found.", M.config.info_notify_level, { title = M.config.notify_title })
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
	end, { nargs = "+", complete = "dir" })

	-- Back-compat alias for old command name
	pcall(vim.api.nvim_del_user_command, "OpengrepQf")
	vim.api.nvim_create_user_command("OpengrepQf", function(opts_)
		vim.schedule(function()
			vim.notify("Deprecated: use :OGrep instead of :OpengrepQf", M.config.info_notify_level, { title = M.config.notify_title })
		end)
		M.run_and_qf(opts_.fargs)
	end, { nargs = "+", complete = "dir" })
end

-- Back-compat: initialize with defaults so it works out-of-the-box
-- Users can call setup{} later to override; setup clears/refreshes autocmds/commands.
M.setup()

return M
