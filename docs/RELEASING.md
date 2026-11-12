# Releasing

Releases are built and published by
[`.github/workflows/release.yml`](../.github/workflows/release.yml) when a
version tag is pushed.

## Steps

1. Make sure `main` is green in CI.
2. In [CHANGELOG.md](../CHANGELOG.md), rename the **Unreleased** section to the
   new version and date, add a fresh empty **Unreleased** section above it, and
   update the compare links at the bottom:

   ```md
   ## [Unreleased]

   ## [1.1.0] - 2026-12-01
   ### Added
   - …

   [Unreleased]: https://github.com/thienduc12311/Great-display/compare/v1.1.0...HEAD
   [1.1.0]: https://github.com/thienduc12311/Great-display/compare/v1.0.0...v1.1.0
   ```

3. Commit (`Release 1.1.0`) and push to `main`.
4. Tag and push:

   ```sh
   git tag v1.1.0
   git push origin v1.1.0
   ```

The workflow then:

- builds a universal `GreatDisplay.app` with `CFBundleShortVersionString`
  set from the tag,
- packages `GreatDisplay-1.1.0.dmg`, `GreatDisplay-1.1.0.zip` and
  `SHA256SUMS.txt`,
- creates the GitHub release with notes from the `## [1.1.0]` changelog section,
  install instructions, and GitHub's generated list of merged pull requests
  (grouped by label, see [`.github/release.yml`](../.github/release.yml)).

Tags with a pre-release suffix (`v1.1.0-beta.1`) are published as
pre-releases. To rebuild an existing tag, run the **Release** workflow manually
from the Actions tab and enter the tag.

Preview the notes locally with:

```sh
./Scripts/release_notes.sh 1.1.0
```

## Signing and notarization (optional)

Without secrets the app is ad-hoc signed and users have to click
**Open Anyway** once. To ship a notarized build, add these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATE_P12` | `base64 -i DeveloperID.p12` of a *Developer ID Application* certificate with its private key |
| `MACOS_CERTIFICATE_PASSWORD` | Password of that `.p12` |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple ID email used for notarization |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_APP_PASSWORD` | App-specific password from appleid.apple.com |

With them the workflow signs with the hardened runtime, notarizes and staples
both the app and the disk image. Then update the install note in the README,
which tells users about **Open Anyway**.
