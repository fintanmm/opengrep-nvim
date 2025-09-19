# opengrep-nvim

A simple Neovim plugin that integrates the [Opengrep](https://www.opengrep.dev/) tool, designed to work well with `lazy.nvim`.

## Features

- **Automatic Checks on Save (async)**: Runs `opengrep` on the current file after you save it (non-blocking) and optionally notifies you if issues are found.
- **Quickfix Integration**: `:OGrep [directory]` runs an on-demand scan and populates the quickfix list with SARIF findings (defaults to the current working directory).
- **Configurable**: Toggle run-on-save, patterns, notification verbosity, quickfix auto-open, binary path and extra args.

## Prerequisites

- Neovim 0.7+ (uses `vim.system` when available, falls back to `jobstart`)
- The Opengrep CLI binary is named `opengrep` and must be on your system `PATH`.
  - If not found, the plugin will show a one-time notification. You can also set a custom path via `setup{ cmd = "/path/to/opengrep" }`.

## Installation

Add the plugin to your `lazy.nvim` configuration (e.g. `~/.config/nvim/lua/plugins/init.lua`).

```lua
return {
  -- other plugins ...
  {
    'fintanmm/opengrep-nvim',
    cmd = { 'OGrep', 'OpengrepQf' },
    config = function()
      require('opengrep').setup({
        -- Optional configuration (shown with defaults):
        cmd = 'opengrep',      -- name/path of opengrep binary (must be 'opengrep' on PATH by default)
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

If you prefer zero-config, the plugin also initializes with sensible defaults on load. Add `cmd = { 'OGrep', 'OpengrepQf' }` in your `lazy.nvim` spec so commands are available before the plugin is loaded.

## Usage

### Automatic Notifications

When `run_on_save` is enabled, saving a file that matches one of the configured `patterns` runs `opengrep` asynchronously. By default, a notification appears only when issues are found. Enable `notify_on_no_issues` to also show a clean message.

### Manual Quickfix Scan

Run a directory scan and populate the quickfix list:

```
:OGrep [directory]
```

- `[directory]`: Optional directory; defaults to the current working directory.

The plugin runs `opengrep scan --quiet` and reads SARIF output to populate the quickfix list. Use `setup{ cmd_args = { ... } }` to pass additional flags such as `--include=PATTERN` or rules files.

You can also specify rules directly via the plugin config using the `rules` option. This accepts a string (single rules file) or a table (multiple files). Each entry is passed to `opengrep` as a `-f <rule>` flag, for example:

```lua
require('opengrep').setup({
  rules = 'rules',
})

-- or
require('opengrep').setup({
  rules = { 'rules', 'more-rules.yml' },
})
```

Examples:

```
:OGrep
:OGrep ~/my-project
```

After the command runs, the quickfix list is populated and (by default) opened if there are results.

- Use `:cnext` / `:cprev` to navigate.
- Use `:copen` / `:cclose` to open/close the quickfix window.

## Notes

- All external calls execute asynchronously via `vim.system` on Neovim 0.10+, with a `jobstart` fallback otherwise.
- Scans run `opengrep scan --quiet` and write SARIF to a temp file; failures notify with stderr.
- Quickfix parsing reads SARIF locations and maps to `filename`, `lnum`, `col`, and message (with `[ruleId]` when available).
- If the `opengrep` binary is not found on PATH, a one-time notification explains how to install it or configure a custom `cmd` path (usually unnecessary).

## Versioning

- Scheme: Semantic Versioning (SemVer) 2.0.0 — `MAJOR.MINOR.PATCH`.
- Tags: Releases use git tags in the form `vX.Y.Z`.
- Bumps: MAJOR for breaking changes, MINOR for backward-compatible features, PATCH for fixes.
- Conventions: Conventional Commits are used; `feat!` or `BREAKING CHANGE` denotes a MAJOR bump.

