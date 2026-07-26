#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
configured_output_dir=${OUTPUT_DIR:-dist}
if [[ "$configured_output_dir" = /* ]]; then
    output_dir="$configured_output_dir"
else
    output_dir="$project_dir/$configured_output_dir"
fi
if [[ -z "$output_dir" || "$output_dir" == "/" || "$output_dir" == "$project_dir" ]]; then
    print -u2 "Refusing unsafe output directory: $output_dir"
    exit 2
fi

app_version=${APP_VERSION:-}
build_number=${BUILD_NUMBER:-}
if [[ -n "$app_version" && ! "$app_version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    print -u2 "APP_VERSION must use x.y.z format: $app_version"
    exit 2
fi
if [[ -n "$build_number" && ! "$build_number" =~ '^[0-9]+(\.[0-9]+)*$' ]]; then
    print -u2 "BUILD_NUMBER must contain only numeric components: $build_number"
    exit 2
fi

app_dir="$output_dir/Agents Status Bar.app"
contents_dir="$app_dir/Contents"

swift build --package-path "$project_dir" -c release --product AgentsStatusBar
binary_dir=$(swift build --package-path "$project_dir" -c release --show-bin-path)

if [[ "$app_dir" != "$output_dir"/* ]]; then
    print -u2 "Unexpected app output path: $app_dir"
    exit 1
fi

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/AgentsStatusBar" "$contents_dir/MacOS/AgentsStatusBar"
cp -R "$binary_dir/AgentsStatusBar_AgentsStatusCore.bundle" "$contents_dir/Resources/AgentsStatusBar_AgentsStatusCore.bundle"
cp -R "$binary_dir/AgentsStatusBar_AgentsStatusBar.bundle/BrandIcons" "$contents_dir/Resources/BrandIcons"
cp "$project_dir/packaging/Info.plist" "$contents_dir/Info.plist"
if [[ -n "$app_version" ]]; then
    plutil -replace CFBundleShortVersionString -string "$app_version" "$contents_dir/Info.plist"
fi
if [[ -n "$build_number" ]]; then
    plutil -replace CFBundleVersion -string "$build_number" "$contents_dir/Info.plist"
fi
cp -R "$project_dir/Sources/AgentsStatusBar/Resources/en.lproj" "$contents_dir/Resources/en.lproj"
cp -R "$project_dir/Sources/AgentsStatusBar/Resources/ko.lproj" "$contents_dir/Resources/ko.lproj"

signing_identity=${APP_SIGN_IDENTITY:--}
signing_arguments=(--force --options runtime --sign "$signing_identity")
if [[ "$signing_identity" != "-" ]]; then
    signing_arguments+=(--timestamp)
fi
codesign "${signing_arguments[@]}" "$app_dir"
codesign --verify --deep --strict "$app_dir"

print "$app_dir"
