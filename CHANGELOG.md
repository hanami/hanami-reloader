# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Break Versioning](https://www.taoensso.com/break-versioning).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

[Unreleased]: https://github.com/hanami/reloader/compare/v2.3.0...HEAD

## [2.3.0] - 2025-11-12

### Changed

- Skip reloading and print a warning if used in production env. (@krzykamil in #32)

[2.3.0]: https://github.com/hanami/reloader/compare/v2.3.0.beta2...v2.3.0

## [2.3.0.beta2] - 2025-10-17

### Changed

- Pass HANAMI_ENV from ENV to guard-puma in generated `Guardfile`. (@afomera in #33)
- Drop support for Ruby 3.1.

[2.3.0.beta2]: https://github.com/hanami/reloader/compare/v2.3.0.beta1...v2.3.0.beta2

## [2.3.0.beta1] - 2025-10-03

[2.3.0.beta1]: https://github.com/hanami/reloader/compare/v2.2.0...v2.3.0.beta1

## [2.2.0] - 2024-11-05

### Added

- Depend on specific minimum guard and guard-puma versions via gemspec. This ensures that certain bundle gem deprecation warnings do not show when running `hanami server`. (@timriley in #30)

[2.2.0]: https://github.com/hanami/reloader/compare/v2.2.0.rc1...v2.2.0

## [2.2.0.rc1] - 2024-10-29

[2.2.0.rc1]: https://github.com/hanami/reloader/compare/v2.2.0.beta2...v2.2.0.rc1

## [2.2.0.beta2] - 2024-07-16

[2.2.0.beta2]: https://github.com/hanami/reloader/compare/v2.2.0.beta1...v2.2.0.beta2

## [2.2.0.beta1] - 2024-07-16

### Changed

- Drop support for Ruby 3.0.

[2.2.0.beta1]: https://github.com/hanami/reloader/compare/v2.1.0...v2.2.0.beta1

## [2.1.0] - 2024-02-27

[2.1.0]: https://github.com/hanami/reloader/compare/v2.1.0.rc3...v2.1.0

## [2.1.0.rc3] - 2024-02-16

[2.1.0.rc3]: https://github.com/hanami/reloader/compare/v2.1.0.rc2...v2.1.0.rc3

## [2.1.0.rc2] - 2023-11-08

[2.1.0.rc2]: https://github.com/hanami/reloader/compare/v2.1.0.rc1...v2.1.0.rc2

## [2.1.0.rc1] - 2023-11-02

### Fixed

- Ensure to reload app when actions, views, and templates, are touched. (@jodosha)
- Fixed incorrect regular expression in `Guardfile`. (@jodosha)

[2.1.0.rc1]: https://github.com/hanami/reloader/compare/v2.1.0.beta2...v2.1.0.rc1

## [2.1.0.beta2] - 2023-10-04

### Added

- When running `hanami new`, generate `Guardfile` that excludes static assets from triggering an app reload. (@jodosha)

[2.1.0.beta2]: https://github.com/hanami/reloader/compare/v2.1.0.beta1...v2.1.0.beta2

## [2.1.0.beta1] - 2023-06-29

[2.1.0.beta1]: https://github.com/hanami/reloader/compare/v2.0.2...v2.1.0.beta1

## [2.0.2] - 2022-12-25

### Added

- Official support for Ruby 3.2. (@jodosha)

[2.0.2]: https://github.com/hanami/reloader/compare/v2.0.1...v2.0.2

## [2.0.1] - 2022-12-06

### Fixed

- Ensure `hanami server` to respect HTTP port used in `.env` or the value given as CLI argument (`--port`). (@jodosha)

[2.0.1]: https://github.com/hanami/reloader/compare/v2.0.0...v2.0.1

## [2.0.0] - 2022-11-22

### Added

- Use Zeitwerk to autoload the gem. (@timriley)
- Generate new apps by requiring `guard-puma` `~> 0.8`. (@jodosha)
- Run bundle install after modifying `Gemfile`. (@timriley)

### Fixed

- Ensure to use the given HTTP port. (@jodosha)

[2.0.0]: https://github.com/hanami/reloader/compare/v2.0.0.rc1...v2.0.0

## [2.0.0.rc1] - 2022-11-08

### Changed

- Follow `hanami` versioning. (@jodosha)

[2.0.0.rc1]: https://github.com/hanami/reloader/compare/v1.0.0.beta4...v2.0.0.rc1

## [1.0.0.beta4] - 2022-10-24

### Changed

- Add help message to `hanami server` command. (@jodosha in #14)

[1.0.0.beta4]: https://github.com/hanami/reloader/compare/v1.0.0.beta3...v1.0.0.beta4

## [1.0.0.beta3] - 2022-09-21

### Added

- Support for Hanami 2.0. (@jodosha)
- Official support for Ruby 3.0 and 3.1. (@jodosha)

### Changed

- Drop support for Ruby: MRI 2.5, 2.6, and 2.7. (@jodosha)

[1.0.0.beta3]: https://github.com/hanami/reloader/compare/v1.0.0.alpha1...v1.0.0.beta3

## [1.0.0.alpha1] - 2019-01-30

### Added

- Added support for `hanami server --no-code-reloading` to skip code reloading. (@jodosha)
- Added `hanami server --guardfile` option to specify the path to `Guardfile`. It defaults to `Guardfile` at the root of the project. (@jodosha)
- Added support for `hanami generate reloader --puma` to generate Puma specific configuration. (@jodosha)

### Changed

- Drop support for Ruby: MRI 2.3, and 2.4. (@jodosha)
- `hanami generate reloader` generates `Guardfile` (instead of `.hanami.server.guardfile`), with the Guard `:server` group. (@jodosha)
- `hanami server` will look for `Guardfile` at the root of the project instead of `.hanami.server.guardfile`. (@jodosha)

[1.0.0.alpha1]: https://github.com/hanami/reloader/compare/v0.3.0...v1.0.0.alpha1

## [0.3.0] - 2020-02-10

### Added

- Official support for Ruby 2.7.0. (@jodosha)
- Official support for Ruby 2.6.0. (@jodosha)
- Support for `bundler` 2.0+. (@jodosha)

[0.3.0]: https://github.com/hanami/reloader/compare/v0.2.1...v0.3.0

## [0.2.1] - 2018-01-23

### Fixed

- Avoid Guard prompt when shutting down the server. (@jodosha)

[0.2.1]: https://github.com/hanami/reloader/compare/v0.2.0...v0.2.1

## [0.2.0] - 2017-11-24

### Changed

- Use `.hanami.server.guardfile` instead of `Guardfile` to avoid conflicts with other `guard` plugins. (@mereghost)

[0.2.0]: https://github.com/hanami/reloader/compare/v0.1.0...v0.2.0

## [0.1.0] - 2017-11-01

### Added

- Added Hanami command `hanami generate reloader`. (@jodosha)
- Code reloading based on `guard`. (@jodosha)

[0.1.0]: https://github.com/hanami/reloader/releases/tag/v0.1.0
