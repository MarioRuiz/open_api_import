# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2026-03-17

### Added
- OpenAPI 3.1 support: handles nullable type arrays (`type: ["string", "null"]`) and `examples` keyword (plural)
- `OpenApiImport::ParseError` exception class for parse failures (instead of `exit!`)
- `OpenApiImport::VERSION` constant
- `return_data` option to get generated code as a Hash without writing files
- `--version` / `-v` CLI flag
- `--dry_run` / `-d` CLI flag to preview output without writing files
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) testing Ruby 3.0-3.4
- RuboCop configuration (`.rubocop.yml`)
- Unit tests for all helper modules (`get_examples`, `get_patterns`, `filter`, `get_required_data`, `pretty_hash_symbolized`, `get_data_all_of_bodies`)
- Feature tests for `mock_response`, `silent`, error handling, `return_data`, and OAS 3.1
- `after(:suite)` cleanup in spec_helper to remove generated test artifacts
- `CHANGELOG.md`

### Changed
- **BREAKING**: `exit!` on parse failure replaced with `raise OpenApiImport::ParseError` -- callers should rescue this
- **BREAKING**: Minimum Ruby version raised from 2.7 to 3.0
- `rescue Exception` replaced with `rescue StandardError` throughout (no longer swallows Ctrl-C/OOM)
- `eval()` calls removed -- replaced with safe hash construction and `load` for file validation
- `String` monkey-patching (`snake_case`/`camel_case`) replaced with Ruby refinements (`OpenApiImportStringExt`)
- `include LibOpenApiImport` moved from top-level (global namespace) into `OpenApiImport` class via `extend`
- Shell commands (`rufo`, `ruby -c`) now use `Shellwords.shellescape` for path safety
- `activesupport` constraint relaxed from `~> 6.1` to `>= 6.1, < 8.0` (supports Rails 7)
- `rufo` constraint relaxed from `~> 0.16.1` to `~> 0.16`
- Input data mutations reduced (non-destructive `gsub` instead of `gsub!`, local variables instead of modifying input hashes)
- Repeated `rufo` formatting + syntax check code extracted into `format_and_check_file` helper method
- `kind_of?` standardized to `is_a?`, `.keys.include?` to `.key?`
- Ruby version comparison uses `Gem::Version` instead of string comparison
- Output messages now display relative paths (as provided by the user) instead of expanded absolute paths

### Fixed
- Bug in `get_examples.rb`: `val.include?("'")` was checking hash keys instead of string content
- Array modification during iteration in `get_required_data.rb` (now collects and concatenates after)
- `filter.rb`: nil guard added for nested key access (`result[key] ||= {}`)
- `get_patterns`: simple-type array items (e.g., `{type: "string"}`) now correctly produce `[:'string']` patterns without relying on mutation side-effects from `get_examples`
- `build_example_value`: array types now recurse into items schema instead of returning empty `[]`, restoring type-hinted examples like `["string"]` and `[{...}]`

### Deprecated
- Travis CI configuration (`.travis.yml`) -- superseded by GitHub Actions
