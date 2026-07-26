# Homebrew distribution

[한국어](HOMEBREW.ko.md) | **English**

Agents Status Bar is distributed as a binary Cask through the shared
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap). The Cask downloads
the versioned ZIP from GitHub Releases and verifies its SHA-256 checksum.

## User commands

Install:

```bash
brew install --cask 90ms/tap/agents-status-bar
open -a "Agents Status Bar"
```

Update:

```bash
brew update
brew upgrade --cask agents-status-bar
```

Uninstall the app while preserving settings and history:

```bash
brew uninstall --cask agents-status-bar
```

Remove the app and its local settings and history:

```bash
brew uninstall --cask --zap agents-status-bar
```

## Maintainer flow

The release workflow publishes `AgentsStatusBar-<version>.zip` and its checksum
for every stable `v<major>.<minor>.<patch>` tag. When `HOMEBREW_TAP_TOKEN` is
configured, it renders the new Cask and opens a pull request against
`90ms/homebrew-tap`; it never merges that pull request automatically.

The token needs permission to push a branch and open a pull request in the tap
repository. The tap CI installs the Cask on an Apple silicon macOS runner,
validates the application bundle and code signature, performs a strict audit,
and uninstalls it before the pull request is merged.

To render a Cask manually:

```bash
./Scripts/render_homebrew_cask.sh \
  <version> \
  <release-zip-sha256> \
  /path/to/homebrew-tap/Casks/agents-status-bar.rb
```

The in-repository `Casks/agents-status-bar.rb` remains a fixture for renderer
tests and supports the legacy explicit-URL tap installation.
