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
app_version_pattern='^[0-9]+\.[0-9]+\.[0-9]+$'
build_number_pattern='^[0-9]+(\.[0-9]+)*$'
if [[ -n "$app_version" && ! "$app_version" =~ $app_version_pattern ]]; then
    print -u2 "APP_VERSION must use x.y.z format: $app_version"
    exit 2
fi
if [[ -n "$build_number" && ! "$build_number" =~ $build_number_pattern ]]; then
    print -u2 "BUILD_NUMBER must contain only numeric components: $build_number"
    exit 2
fi

app_dir="$output_dir/Tokeni Bar.app"
contents_dir="$app_dir/Contents"

swift build --package-path "$project_dir" -c release --product TokeniBar
binary_dir=$(swift build --package-path "$project_dir" -c release --show-bin-path)

if [[ "$app_dir" != "$output_dir"/* ]]; then
    print -u2 "Unexpected app output path: $app_dir"
    exit 1
fi

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/TokeniBar" "$contents_dir/MacOS/TokeniBar"
cp -R "$binary_dir/TokeniBar_TokeniCore.bundle" "$contents_dir/Resources/TokeniBar_TokeniCore.bundle"
cp -R "$binary_dir/TokeniBar_TokeniBar.bundle/BrandIcons" "$contents_dir/Resources/BrandIcons"
cp -R "$binary_dir/TokeniBar_TokeniBar.bundle/CompanionAssets" "$contents_dir/Resources/CompanionAssets"
cp "$project_dir/packaging/Info.plist" "$contents_dir/Info.plist"
if [[ -n "$app_version" ]]; then
    plutil -replace CFBundleShortVersionString -string "$app_version" "$contents_dir/Info.plist"
fi
if [[ -n "$build_number" ]]; then
    plutil -replace CFBundleVersion -string "$build_number" "$contents_dir/Info.plist"
fi
cp -R "$project_dir/Sources/TokeniBar/Resources/en.lproj" "$contents_dir/Resources/en.lproj"
cp -R "$project_dir/Sources/TokeniBar/Resources/ko.lproj" "$contents_dir/Resources/ko.lproj"

signing_identity=${APP_SIGN_IDENTITY:--}
signing_arguments=(--force --options runtime --sign "$signing_identity")
if [[ "$signing_identity" != "-" ]]; then
    signing_arguments+=(--timestamp)
fi
codesign "${signing_arguments[@]}" "$app_dir"
codesign --verify --deep --strict "$app_dir"

print "$app_dir"
