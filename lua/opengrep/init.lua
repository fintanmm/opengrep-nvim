-- Main plugin file for the opengrep-nvim repository.
-- This file is automatically loaded by LazyVim.

-- Create a table to hold our plugin's functions and commands.
local M = {}

--- Function to run opengrep on the current buffer and display a notification.
M.run_and_notify = function()
	-- Get the full path of the current buffer.
	local filename = vim.api.nvim_buf_get_name(0)

	-- If the buffer has no name (e.g., an empty buffer), do nothing.
	if filename == "" then
		return
	end

	-- Run opengrep on the single file.
	local cmd = { "opengrep", filename }
	local output = vim.fn.system(cmd)

	if output == "" then
		vim.notify("opengrep: No issues found in " .. vim.fn.fnamemodify(filename, ":t"), vim.log.levels.INFO)
	else
		local lines = vim.split(output, "\n", { plain = true })
		local issue_count = #lines - 1 -- Account for the trailing newline

		-- Get the first line of the output for a brief summary.
		local first_line = lines[1]

		vim.notify(
			string.format(
				"opengrep: Found %d issue%s in %s. First issue: %s",
				issue_count,
				issue_count ~= 1 and "s" or "",
				vim.fn.fnamemodify(filename, ":t"),
				first_line
			),
			vim.log.levels.WARN,
			{ title = "Opengrep Issues" }
		)
	end
end

--- Function to run opengrep and populate the quickfix list for manual review.
--- @param args table The arguments passed to the command.
M.run_and_qf = function(args)
	local pattern = args[1]
	local directory = args[2] or vim.fn.getcwd()

	if not pattern then
		vim.notify("Usage: :OpengrepQf {pattern} [directory]", vim.log.levels.INFO)
		return
	end

	local cmd = { "opengrep", pattern, directory }
	local output = vim.fn.system(cmd)
	local lines = vim.split(output, "\n", {})
	local qf_list = {}

	for _, line in ipairs(lines) do
		if line ~= "" then
			local parts = vim.split(line, ":", { plain = true })

			if #parts >= 3 then
				local filename = parts[1]
				local lnum = tonumber(parts[2])
				local text = table.concat(parts, ":", 4)
				local col = tonumber(parts[3]) or 1

				table.insert(qf_list, {
					filename = filename,
					lnum = lnum,
					col = col,
					text = text,
				})
			end
		end
	end

	vim.fn.setqflist(qf_list)

	if #qf_list > 0 then
		vim.cmd("copen")
		vim.notify(#qf_list .. " matches found in quickfix list.", vim.log.levels.INFO)
	else
		vim.notify("No matches found.", vim.log.levels.INFO)
	end
end

-- Create the autocommand group to avoid duplicate autocmds.
vim.api.nvim_create_augroup("OpengrepGroup", { clear = true })

-- Trigger the notification function whenever a file is saved.
vim.api.nvim_create_autocmd("BufWritePost", {
	group = "OpengrepGroup",
	-- Restrict to specific filetypes for performance.
	pattern = {
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
	callback = function()
		M.run_and_notify()
	end,
})

-- Create the user command to populate the quickfix list.
vim.api.nvim_create_user_command("OpengrepQf", function(opts)
	M.run_and_qf(opts.args)
end, { nargs = "*", complete = "file" })

return M
