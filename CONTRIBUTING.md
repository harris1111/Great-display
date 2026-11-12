# Contributing to Great Display

Thanks for helping. Great Display is a small project, so the process is light.

## Reporting bugs and display problems

Displays, docks and adapters behave very differently, so a good report makes
the difference. Use the **Bug report** issue template and include:

- macOS version and Mac model (Apple Silicon or Intel).
- The monitor model and how it is connected (USB-C, HDMI, a dock, DisplayLink…).
- The output of the probe command:

  ```sh
  /Applications/GreatDisplay.app/Contents/MacOS/GreatDisplay --probe
  ```

- For brightness/DDC problems, also `--ddc-caps <displayID>` and
  `--ddc-diag <displayID>` (the display ID is in the probe output).

## Development setup

Requirements: macOS 14 or later and a recent Xcode.

```sh
make              # build dist/GreatDisplay.app
make run          # build and launch
make probe        # print the display inventory
make package      # universal build + DMG/ZIP
```

The app is a Swift package with three targets:

| Target | Contents |
| --- | --- |
| `GDCBridge` | Objective-C bridge to system display facilities |
| `GDCore` | Display inventory, brightness, DDC/CI, virtual screens, streaming, persistence |
| `GreatDisplay` | App delegate, menu bar, SwiftUI menu and Settings, CLI entry points |

[docs/TECHNICAL-NOTES.md](docs/TECHNICAL-NOTES.md) explains the trickier parts
(DDC/CI timing, HiDPI rules, signing and permissions).

### Testing your change

There is no hardware-free test suite for most display behaviour, so:

- Run `GreatDisplay --self-test`. It creates a temporary virtual screen and
  checks resolutions, refresh rates, image adjustments and
  disconnect/reconnect without touching your physical displays.
- Exercise the feature you changed on real hardware and say in the pull
  request what you tested it on (macOS version, displays, connection).
- Make sure the CI build passes (it builds a universal binary).

## Pull requests

1. Fork the repository and create a branch from `main`.
2. Keep pull requests focused: one fix or feature per PR.
3. Follow the existing code style (Swift API design guidelines, 4-space
   indentation, no force unwraps on system API results).
4. Add an entry under **Unreleased** in [CHANGELOG.md](CHANGELOG.md), in the
   matching `Added`, `Changed`, `Fixed` or `Removed` group. Release notes are
   built from this file.
5. Fill in the pull request template.

Private system interfaces must be resolved at runtime and fail gracefully, so
the app keeps working (with reduced features) when a macOS update changes
them.

## Code of Conduct

By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Contributions are accepted under the project's [MIT License](LICENSE).
