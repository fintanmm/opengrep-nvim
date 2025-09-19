# opengrep-nvim

A simple Neovim plugin that integrates the [Opengrep](https://www.opengrep.dev/) tool, designed to work well with `lazy.nvim`.

## Features

- **Automatic Checks on Save (async)**: Runs `opengrep` on the current file after you save it (non-blocking) and optionally notifies you if issues are found.
- **Quickfix Integration**: `:OpengrepQf` to run a manual search and populate the quickfix list with results.
- **Configurable**: Toggle run-on-save, patterns, notification verbosity, quickfix auto-open, binary path and extra args.

## Prerequisites

- Neovim 0.7+
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
        notify_on_no_issues = false, -- notify when file is clean
        notify_title = 'Opengrep',   -- notification title
        open_qf_on_results = true,   -- open quickfix if matches found
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
:OpengrepQf {pattern} [directory]
```

- `{pattern}`: Required search pattern.
- `[directory]`: Optional directory; defaults to the current working directory.

Examples:

```
:OpengrepQf "my_function"
:OpengrepQf TODO ~/my-project
```

After the command runs, the quickfix list is populated and (by default) opened if there are results.

- Use `:cnext` / `:cprev` to navigate.
- Use `:copen` / `:cclose` to open/close the quickfix window.

## Notes

- All external calls are executed asynchronously using `vim.system` when available (Neovim 0.10+), with a `jobstart` fallback on older versions.
- Errors and non-zero exit codes are surfaced clearly; no-match output is treated as "no results" rather than an error.
- Quickfix entries are parsed robustly from lines of the form `file:lnum:col:text`. If your environment emits a different format, open an issue or adjust parsing.
