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

`--install-app` safely links the current Homebrew Formula app into
`~/Applications/Tokeni Bar.app`. It recognizes both Homebrew's stable Formula
path and its versioned Cellar path, so Formula upgrades replace the managed link
automatically.

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
The app explicitly passes Homebrew's `--formula` option so it only inspects and
upgrades the Formula even though a Cask with the same name is also published.
When launched from Finder, in-app updates also provide Homebrew with the user's
home directory and executable search paths, so a Terminal shell setup is not
required.
After a manual Terminal update, run `tokeni-bar --install-app` again so the app
link points at the current version.

If version 0.25.1 or earlier reports a Formula/Cask ambiguity, perform this
one-time update and restart the app. There is no need to disable trust checks
globally.

```bash
brew trust --formula 90ms/tap/tokeni-bar
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
```

<a id="migrating-from-the-cask"></a>

## Migrating from the Cask

When **Settings → General → App Updates** shows the Cask migration guide,
perform this one-time transition. Do not use `--zap` if you want to retain pet
state, usage history, and settings.

```bash
# Quit Tokeni Bar first.
brew uninstall --cask tokeni-bar
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

The Formula creates a managed link at `~/Applications/Tokeni Bar.app` pointing
to the Homebrew app. Uninstalling the Cask removes its app bundle
but, without `--zap`, does not delete
`~/Library/Application Support/TokeniBar` or existing preferences.

Verify the result with:

```bash
brew list --formula tokeni-bar
tokeni-bar --print-app-path
```

The launcher refuses to overwrite a user-created app or a symlink unrelated to
the Formula at `~/Applications/Tokeni Bar.app`. Verify and move that item
yourself, then run `tokeni-bar --install-app` again.

## Direct installation from GitHub Releases

GitHub Release ZIPs are also published as ad-hoc signed builds without Apple
Developer ID signing or notarization. If macOS blocks the first launch, you may
need to allow it explicitly in **System Settings → Privacy & Security**.

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
- If Homebrew asks you to choose between the Formula and Cask, add `--formula`
  to the command. In-app updates do this automatically starting with 0.25.2.
- If an in-app update reports a `$HOME` error, update to the latest version and
  retry. Older versions can be updated from Terminal.
- If an older version opens after an update, run
  `tokeni-bar --install-app` again.
- If the app exits immediately, update the Formula in Terminal and recreate
  the app link.
