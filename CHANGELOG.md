# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning (SemVer).

## [Unreleased]

### Added
- Backward-compatible `:OpengrepQf` alias with deprecation notice
- `lazy.nvim` command triggers in README to avoid E492 on first use
- Semantic Versioning policy documented in README
- Keep a Changelog file and GitHub Actions workflow to publish releases on tags
- SARIF-based integration: run `opengrep scan --quiet` and parse SARIF for notifications and quickfix results

### Changed
- `:OGrep` now scans a directory (`:OGrep [directory]`) instead of taking a pattern; it populates quickfix from SARIF results
- Notifications for save-time checks show count and first finding using SARIF
- README updated for SARIF, `--quiet`, and new `:OGrep [directory]` signature

## [0.1.0] - 2025-09-19

### Added
- Initial plugin scaffolding and main functionality for Opengrep integration
- Async execution (prefers `vim.system`, falls back to `jobstart`)
- Quickfix integration with robust parsing (`file:lnum:col:text` with fallback)
- Java filetype added to default run-on-save patterns
- User configuration via `setup{}` including `cmd`, `cmd_args`, `run_on_save`, patterns, notify levels, and quickfix options

### Changed
- Command renamed from `:OpengrepQf` to `:OGrep` (later, a back-compat alias was added in Unreleased)

### Docs
- Comprehensive README with installation, usage, and configuration examples

[Unreleased]: https://github.com/fintanmm/opengrep-nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fintanmm/opengrep-nvim/releases/tag/v0.1.0
