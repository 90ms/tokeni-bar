#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
"$project_dir/Tests/Scripts/HomebrewCaskTests.sh"
"$project_dir/Tests/Scripts/HomebrewFormulaTests.sh"
"$project_dir/Tests/Scripts/ReleaseNotesTests.sh"
"$project_dir/Tests/Scripts/GitHubWorkflowTests.sh"
"$project_dir/Tests/Scripts/LocalizationCatalogTests.sh"
"$project_dir/Scripts/validate_companion_assets.sh"

args=(--enable-swift-testing --disable-xctest)
developer_dir=$(xcode-select -p 2>/dev/null || true)

# Standalone Command Line Tools contain Testing.framework outside SwiftPM's default search path.
if [[ "$developer_dir" == */CommandLineTools ]]; then
    framework_dir="$developer_dir/Library/Developer/Frameworks"
    interop_dir="$developer_dir/Library/Developer/usr/lib"
    args+=(
        -Xswiftc -F
        -Xswiftc "$framework_dir"
        -Xlinker "-F$framework_dir"
        -Xlinker -rpath
        -Xlinker "$framework_dir"
        -Xlinker -rpath
        -Xlinker "$interop_dir"
    )
fi

swift test "${args[@]}"
