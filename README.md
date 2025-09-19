# opengrep-nvim

A simple Neovim plugin that integrates the [Opengrep](https://www.opengrep.dev/) tool, designed to work well with `lazy.nvim`.

## Features

- **Automatic Checks on Save (async)**: Runs `opengrep` on the current file after you save it (non-blocking) and optionally notifies you if issues are found.
- **Quickfix Integration**: `:OGrep` to run a manual search and populate the quickfix list with results. Accepts a required search pattern and optional directory.
- **Configurable**: Toggle run-on-save, patterns, notification verbosity, quickfix auto-open, binary path and extra args.

## Prerequisites

- Neovim 0.7+ (uses `vim.system` when available, falls back to `jobstart`)
- The `opengrep` binary installed and available in your system `PATH`.
  - If not found, the plugin will show a one-time notification. You can also set a custom path via `setup{ cmd = "/path/to/opengrep" }`.

## Installation

Add the plugin to your `lazy.nvim` configuration (e.g. `~/.config/nvim/lua/plugins/init.lua`).

```lua
return {
  -- other plugins ...
  {
    'fintanmm/opengrep-nvim',
    config = function()
      require('opengrep').setup({
        -- Optional configuration (shown with defaults):
        cmd = 'opengrep',      -- path to opengrep binary
        cmd_args = {},         -- extra args passed to every call
        run_on_save = true,    -- enable BufWritePost checks
        patterns = {           -- which files trigger run_on_save
          '*.lua','*.py','*.sh','*.c','*.cpp','*.js','*.ts','*.html','*.css','*.h','*.hpp','*.c++','*.java'
        },
        notify_on_no_issues = false,       -- notify when file is clean
        notify_title = 'Opengrep',         -- notification title
        issue_notify_level = vim.log.levels.WARN, -- severity for issue notifications
        info_notify_level = vim.log.levels.INFO,  -- severity for info/clean messages
        open_qf_on_results = true,         -- open quickfix if matches found
      })
    end,
  },
}
```

If you prefer zero-config, the plugin also initializes with sensible defaults on load.

## Usage

### Automatic Notifications

When `run_on_save` is enabled, saving a file that matches one of the configured `patterns` runs `opengrep` asynchronously. By default, a notification appears only when issues are found. Enable `notify_on_no_issues` to also show a clean message.

### Manual Quickfix Search

Run a manual search and populate the quickfix list:

```
:OGrep {pattern} [directory]
```

- `{pattern}`: Required search pattern.
- `[directory]`: Optional directory; defaults to the current working directory.

Examples:

```
:OGrep "my_function"
:OGrep TODO ~/my-project
```

After the command runs, the quickfix list is populated and (by default) opened if there are results.

- Use `:cnext` / `:cprev` to navigate.
- Use `:copen` / `:cclose` to open/close the quickfix window.

## Notes

- All external calls execute asynchronously via `vim.system` on Neovim 0.10+, with a `jobstart` fallback otherwise.
- Non-zero exit codes without stdout are treated as errors; empty stdout with zero exit code is treated as "no results".
- Quickfix parsing handles `file:lnum:col:text` and falls back to a colon-split heuristic for resilience.
- If `opengrep` is not found, a one-time notification explains how to install or configure a custom `cmd` path.
