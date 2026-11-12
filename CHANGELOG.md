# Changelog

All notable changes to Great Display are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

Each release's notes on GitHub are taken from its section below, so add your
change under **Unreleased** in the same pull request.

## [Unreleased]

## [1.0.0] - 2026-11-12

First public release.

### Added

- **Menu bar app** with a collapsible section per display: connect switch,
  combined brightness and resolution sliders, and a "more options" level with
  feature panels. Option-click opens Settings, right-click opens a quick menu.
- **Resolutions and HiDPI**: resolution slider with Default/Native markers, a
  Display Mode list with HiDPI/LoDPI, refresh-rate and aspect-ratio filters,
  and a strict HiDPI toggle that keeps the refresh rate. Mode changes run off
  the main thread with a per-display fade.
- **Brightness** through native panel brightness on Apple displays, DDC/CI on
  external monitors and gamma-table dimming everywhere, combined into a single
  slider.
- **DDC/CI device control**: contrast, volume and mute, input source, picture
  modes, colour presets, hardware RGB gain, sharpness, standby and restore
  actions, read from the monitor's capabilities string. Raw VCP read/write in
  Settings.
- **Image adjustments** per display: gamma, colour temperature, software
  contrast, RGB gain, invert, suspend and reset.
- **Virtual screens** from aspect-ratio presets, custom ratios or a matched
  display, with about 40 sizes per ratio, live resize, optional 16K ceiling,
  mirror target, auto-start and associations with physical displays
  (auto-connect, enforced mirroring, auto-stream, orientation following).
- **Streaming** a display full-screen onto another display or onto itself, with
  pointer, scaling, crop, flip, rotation, zoom, underscan and FPS options, and
  an interactive mode that routes the pointer and keyboard through the stream.
- **Mirroring**, main display assignment, rotation, HDR toggle, logical
  connect/disconnect and display arrangement.
- **System colours**: Dark Mode, Night Shift and True Tone toggles; Prevent
  Sleep.
- **Keyboard**: brightness keys (and F14/F15) with OSD, and volume keys routed
  to DDC volume when audio goes to a DisplayPort/HDMI monitor.
- **Glass-style OSD** for brightness, contrast, volume and errors.
- **Settings window** with a Displays overview, a page per display, Virtual
  Screens, Application, Menu, Keyboard and About pages; launch at login.
- **Command line interface** (`--probe`, `--set-resolution`, `--ddc-read`,
  `--mirror`, `--self-test` and more) and `greatdisplay://` deep links.
- Universal (Apple Silicon and Intel) DMG and ZIP builds published by GitHub
  Actions.

[Unreleased]: https://github.com/thienduc12311/Great-display/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/thienduc12311/Great-display/releases/tag/v1.0.0
