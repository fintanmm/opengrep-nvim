# opengrep-nvim

A simple Neovim plugin that integrates the [Opengrep](https://www.opengrep.dev/) tool, specifically designed for use with `lazy.nvim`.

## Features

- **Automatic File Linting**: Automatically runs `opengrep` on the current file after you save it and displays a notification if any issues are found.
- **Quickfix Integration**: A user command `:OpengrepQf` to run a manual search and populate the quickfix list for easy navigation.

## Prerequisites

- Neovim 0.5+
- The `opengrep` tool must be installed and available in your system's PATH.

## Installation

Add the plugin to your `lazy.nvim` configuration. This is typically in `~/.config/nvim/lua/plugins/init.lua` or a similar file.

```lua
return {
  -- Other plugins...
  'fintanmm/opengrep-nvim',
}
```

Restart Neovim. LazyVim will automatically clone the repository and load the plugin.

## Usage

### Automatic Notifications

Just work as you normally would. When you save a file that matches one of the specified patterns (`lua`, `py`, `sh`, `c`, `cpp`, `js`, `ts`, `html`, `css`, `h`, `hpp`, `c++`, `java`), a notification will pop up in the corner of your screen indicating whether issues were found.

### Manual Quickfix Search

Use the user command to run a manual search and populate the quickfix list for easy navigation.

```
:OpengrepQf {pattern} [directory]
```

- `{pattern}`: The search pattern you want to find. This is a required argument.
- `[directory]`: An optional directory to search in. If not provided, it defaults to the current working directory.

#### Examples

Search for the string `"my_function"` in the current directory:

```
:OpengrepQf "my_function"
```

Search for the string `"TODO"` in the `~/my-project` directory:

```
:OpengrepQf "TODO" ~/my-project
```

After the command runs, the quickfix list will be populated with the results.

- Use `:cnext` to jump to the next match.
- Use `:cprev` to jump to the previous match.
- Use `:copen` to open the quickfix window.
- Use `:cclose` to close the quickfix window.
