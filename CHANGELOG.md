# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning (SemVer).

## [Unreleased]

### Added
- Initial CHANGELOG using Keep a Changelog format
- GitHub Actions workflow to publish releases on tags

## [0.1.0] - 2025-09-19

### Added
- Initial functionality integrating `opengrep` CLI
- Async execution (prefers `vim.system`, falls back to `jobstart`)
- Quickfix population from opengrep output
- `:OGrep` command for manual searches

### Changed
- Rename command from `:OpengrepQf` to `:OGrep` (backward-compatible alias retained)

### Docs
- README installation, usage, and configuration examples

[Unreleased]: https://github.com/fintanmm/opengrep-nvim/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fintanmm/opengrep-nvim/releases/tag/v0.1.0
