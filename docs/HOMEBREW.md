# Homebrew distribution

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
repository. The tap CI should install the Cask, run its test, and perform a
strict audit before the pull request is merged.

To render a Cask manually:

```bash
./Scripts/render_homebrew_cask.sh \
  0.5.1 \
  968d7845bef67db6d185822ffe588c7cede5c4049f61d076fc308f72e2ee5032 \
  /path/to/homebrew-tap/Casks/agents-status-bar.rb
```

The in-repository `Casks/agents-status-bar.rb` remains a fixture for renderer
tests and supports the legacy explicit-URL tap installation.
