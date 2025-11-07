# Hanami::Reloader

Code reloading for Hanami 2

## v2.3.0

### Changed

- Skip reloading and print a warning if used in production env. (@krzykamil in #32)

## v2.3.0.beta2 - 2025-10-17

### Changed

- [Andrea Fomera] Pass HANAMI_ENV from ENV to guard-puma in generated `Guardfile`. (#33)
- Drop support for Ruby 3.1

## v2.3.0.beta1 - 2025-10-03

## v2.2.0 - 2024-11-05

### Added

- [Tim Riley] Depend on specific minimum guard and guard-puma versions via gemspec. This ensures that certain bundle gem deprecation warnings do not show when running `hanami server`. (#30)

## v2.2.0.rc1 - 2024-10-29

## v2.2.0.beta2 - 2024-07-16

## v2.2.0.beta1 - 2024-07-16

### Changed

- Drop support for Ruby 3.0

## v2.1.0 - 2024-02-27

## v2.1.0.rc3 - 2024-02-16

## v2.1.0.rc2 - 2023-11-08

## v2.1.0.rc1 - 2023-11-02

### Fixed

- [Luca Guidi] Ensure to reload app when actions, views, and templates, are touched.
- [Luca Guidi] Fixed incorrect regular expression in `Guardfile`

## v2.1.0.beta2 - 2023-10-04

### Added

- [Luca Guidi] When running `hanami new`, generate `Guardfile` that excludes static assets from triggering an app reload

## v2.1.0.beta1 - 2023-06-29

## v2.0.2 - 2022-12-25

### Added

- [Luca Guidi] Official support for Ruby 3.2

## v2.0.1 - 2022-12-06

### Fixed

- [Luca Guidi] Ensure `hanami server` to respect HTTP port used in `.env` or the value given as CLI argument (`--port`)

## v2.0.0 - 2022-11-22

### Added

- [Tim Riley] Use Zeitwerk to autoload the gem
- [Luca Guidi] Generate new apps by requiring `guard-puma` `~> 0.8`
- [Tim Riley] Run bundle install after modifying `Gemfile`

### Fixed

- [Luca Guidi] Ensure to use the given HTTP port

## v2.0.0.rc1 - 2022-11-08

### Changed

- [Luca Guidi] Follow `hanami` versioning

## v1.0.0.beta4 - 2022-10-24

### Changed

- [Luca Guidi] Add help message to `hanami server` command (#14)

## v1.0.0.beta3 - 2022-09-21

### Added

- [Luca Guidi] Support for Hanami 2.0
- [Luca Guidi] Official support for Ruby 3.0 and 3.1

### Changed

- [Luca Guidi] Drop support for Ruby: MRI 2.5, 2.6, and 2.7.

## v1.0.0.alpha1 - 2019-01-30

### Added

- [Luca Guidi] Added support for `hanami server --no-code-reloading` to skip code reloading.
- [Luca Guidi] Added `hanami server --guardfile` option to specify the path to `Guardfile`. It defaults to `Guardfile` at the root of the project.
- [Luca Guidi] Added support for `hanami generate reloader --puma` to generate Puma specific configuration.

### Changed

- [Luca Guidi] Drop support for Ruby: MRI 2.3, and 2.4.
- [Luca Guidi] `hanami generate reloader` generates `Guardfile` (instead of `.hanami.server.guardfile`), with the Guard `:server` group.
- [Luca Guidi] `hanami server` will look for `Guardfile` at the root of the project instead of `.hanami.server.guardfile`.

## v0.3.0 - 2020-02-10

### Added

- [Luca Guidi] Official support for Ruby 2.7.0
- [Luca Guidi] Official support for Ruby 2.6.0
- [Luca Guidi] Support for `bundler` 2.0+

## v0.2.1 - 2018-01-23

### Fixed

- [Luca Guidi] Avoid Guard prompt when shutting down the server

## v0.2.0 - 2017-11-24

### Changed

- [Marcello Rocha] Use `.hanami.server.guardfile` instead of `Guardfile` to avoid conflicts with other `guard` plugins.

## v0.1.0 - 2017-11-01

### Added

- [Luca Guidi] Added Hanami command `hanami generate reloader`
- [Luca Guidi] Code reloading based on `guard`
