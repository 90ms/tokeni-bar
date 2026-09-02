# Release and distribution procedure

[한국어](RELEASING.ko.md) | **English**

Tokeni Bar releases are built from a validated `main` commit and structured
bilingual change fragments. Distribution is complete only after the GitHub
Release is published and the generated Homebrew tap pull request is validated
and merged for both the Formula and Cask.

## 1. Prepare the change

1. Add a unique bilingual fragment under `.changes/` for every user-visible
   source or packaging change.
2. Always pass `--formula` to Formula-oriented Homebrew commands because a Cask
   with the same name is also distributed.
3. Run the relevant validation:

```bash
swift test
swift build
Scripts/validate_companion_assets.sh
Scripts/validate_localizations.sh
Tests/Scripts/ReleaseNotesTests.sh
Tests/Scripts/GitHubWorkflowTests.sh
git diff --check
```

Checks unrelated to the change may be omitted, but always run `swift test` and
`swift build`. If the local toolchain is unavailable, confirm that the PR's
macOS CI performs and passes the equivalent checks.

## 2. Validate the PR and main

1. Commit and push only the intended files on a feature branch.
2. Merge only after both stable checks, `macOS required gate` and
   `Windows required gate`, pass. Both names remain present when path filtering
   skips an unaffected platform. Repository contracts validate release fragments,
   workflows, and Korean/English localization key and format parity.
3. For macOS-impacting changes, confirm Swift tests, the release build, app
   packaging, bundle metadata, and the packaged-executable smoke test. For
   Windows-impacting changes, confirm Swift tests, the native state machine,
   portable packaging, asset validation, and the unpacked-executable smoke test.
4. Wait for the new CI run on the merged `main` commit to pass before creating
   a tag.

## 3. Review release notes and create the tag

Choose the next semantic version based on compatibility and user impact, then
render the release notes before tagging:

```bash
Scripts/render_release_notes.sh <version> /tmp/tokeni-bar-release-notes.md
Scripts/validate_release_notes.sh release <version> /tmp/tokeni-bar-release-notes.md
```

Review the Korean and English content, user actions, and installation commands.
Create and push an annotated tag on the validated `main` merge commit:

```bash
git tag -a v<version> -m "Tokeni Bar <version>" <main-merge-sha>
git push origin v<version>
```

Never move a published tag to another commit. Rerun the `Release` workflow for
the existing tag only when the failure was transient or external. If source or
workflow code must change, create the next patch version and carry every
unpublished fragment forward under a new unique filename before rendering its
notes, as described in `.changes/README.md`.

## 4. Validate the GitHub Release

Confirm that every `Release` workflow step succeeds:

- run the focused Windows release tests;
- build and validate the portable Windows ZIP before publishing anything;
- resolve the tag version and render structured bilingual notes;
- build and ad-hoc sign the macOS application;
- smoke-test the packaged macOS executable without accessing user data;
- create macOS and Windows ZIPs and their SHA-256 files;
- generate GitHub build attestations for both archives;
- publish the release with the validated `--notes-file`;
- open the Homebrew Formula/Cask update pull request.

Verify the published artifacts directly:

```bash
shasum -a 256 -c TokeniBar-<version>.zip.sha256
gh attestation verify TokeniBar-<version>.zip --repo 90ms/tokeni-bar
shasum -a 256 -c Tokeni-Bar-Windows-<version>.zip.sha256
gh attestation verify Tokeni-Bar-Windows-<version>.zip --repo 90ms/tokeni-bar
```

## 5. Complete Homebrew distribution

Merge the generated `90ms/homebrew-tap` pull request with a merge commit only
after all of these checks pass:

- Tokeni Bar Formula source build and launcher-path test;
- Tokeni Bar Cask installation and audit;
- regression checks for the tap's other Formulae and Casks.

After merging, confirm that `Formula/tokeni-bar.rb` and
`Casks/tokeni-bar.rb` point to the new version and their respective SHA-256
values. Distribution is complete after validating the user update path:

```bash
brew update
brew upgrade --formula 90ms/tap/tokeni-bar
tokeni-bar --install-app
```
