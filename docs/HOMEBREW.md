# Homebrew distribution

[한국어](HOMEBREW.ko.md) | **English**

Tokeni Bar's primary distribution path is a source-built Formula in the shared
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap). The Formula
verifies the SHA-256 of a versioned GitHub source archive and builds the app on
the user's Mac. The result is ad-hoc signed, so installation and updates do not
require an Apple Developer ID or the full Xcode application. Current Xcode
Command Line Tools are required.

In-app installation and restart are supported for Formula installs.

## User commands

Install:

```bash
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

`--install-app` safely links the current Cellar app into
`~/Applications/Tokeni Bar.app`.

If the tap was already added and Homebrew reports a trust error, trust only
this Formula:

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula tokeni-bar
```

Update:

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
```

Uninstall the app while preserving settings and history:

```bash
tokeni-bar --uninstall-app
brew uninstall --formula tokeni-bar
```

## In-app updates

When the GitHub Releases check finds a new version, choose **Install & Restart**
under **Settings → General → App Updates**.

Update checks are automatic; installation starts only after an explicit click.
After a manual Terminal update, run `tokeni-bar --install-app` again so the app
link points at the current version.

## Direct installation from GitHub Releases

GitHub Release ZIPs are published only when the complete Developer ID signing
and Apple notarization configuration is available. This is distinct from the
Formula's local ad-hoc build.

```bash
gh attestation verify TokeniBar-<version>.zip --repo 90ms/tokeni-bar
shasum -a 256 -c TokeniBar-<version>.zip.sha256
```

Download the ZIP and checksum from the
[latest GitHub release](https://github.com/90ms/tokeni-bar/releases/latest).
Use the commands above to verify build provenance and file integrity before
launching it.

## Troubleshooting

- For a trust error, confirm that only the `tokeni-bar` Formula—not the entire
  tap—was trusted.
- If an older version opens after an update, run
  `tokeni-bar --install-app` again.
- If the app exits immediately, update the Formula in Terminal and recreate
  the app link.
