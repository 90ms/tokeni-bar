# Homebrew distribution

[한국어](HOMEBREW.ko.md) | **English**

Tokeni Bar's primary distribution path is a source-built Formula in the shared
[`90ms/homebrew-tap`](https://github.com/90ms/homebrew-tap). The Formula
verifies the SHA-256 of a versioned GitHub source archive and builds the app on
the user's Mac. The result is ad-hoc signed, so installation and updates do not
require an Apple Developer ID or the full Xcode application. Current Xcode
Command Line Tools are required.

The binary Cask and GitHub Release ZIP remain as transitional compatibility
paths. In-app installation and restart are supported only for Formula installs.

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

1. Locate Homebrew at a known absolute path.
2. Verify that `90ms/tap/tokeni-bar` is installed as a Formula.
3. Run `brew update` and upgrade only that Formula.
4. Relink `~/Applications` to the new Cellar version.
5. Open the new app and terminate the previous process.

Commands use fixed executables and arguments rather than shell command strings.
Update checks are automatic; installation starts only after an explicit click.

<a id="migrating-from-the-cask"></a>

## Migrating from the Cask

```bash
brew trust --cask 90ms/tap/tokeni-bar
brew uninstall --cask tokeni-bar
brew trust --formula 90ms/tap/tokeni-bar
brew install --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

Removing the Cask deletes only its app bundle, so Application Support settings,
usage history, and ByteBot state remain in place.

If Homebrew reports that the Cask is not installed, skip that uninstall step.
Explicit `--formula` and `--cask` flags disambiguate the two packages with the
same token.

## Recovering from an immediate exit

Formula apps before `v0.7.2` could exit when opening the menu because their
packaged SwiftPM resource bundle was missing. Since the in-app updater is not
reachable, update in Terminal and relink the current Cellar app:

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
tokeni-bar
```

## Maintainer flow

The release workflow publishes `TokeniBar-<version>.zip` and its checksum for
every stable `v<major>.<minor>.<patch>` tag and calculates the GitHub tag source
archive SHA-256. When `HOMEBREW_TAP_TOKEN` is configured, it renders the new
Formula and compatibility Cask and opens a pull request against
`90ms/homebrew-tap`. It never merges that pull request automatically.

The token needs permission to push a branch and open a pull request in the tap
repository. Tap CI builds the Formula with standalone Command Line Tools,
validates the app bundle, launcher, and code signature, then runs tests, a
strict audit, and uninstall. App repository CI also checks the packaged ByteBot
and provider-icon resources.

To render a Formula manually:

```bash
./Scripts/render_homebrew_formula.sh \
  <version> \
  <source-tarball-sha256> \
  /path/to/homebrew-tap/Formula/tokeni-bar.rb
```

The in-repository `Formula/tokeni-bar.rb` and `Casks/tokeni-bar.rb` are renderer
fixtures. The Cask renderer remains during the compatibility ZIP period.
