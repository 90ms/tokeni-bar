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

swift_build_arguments=(--package-path "$project_dir" -c release)
if [[ "${SWIFT_BUILD_DISABLE_SANDBOX:-0}" == "1" ]]; then
    swift_build_arguments+=(--disable-sandbox)
fi
swift build "${swift_build_arguments[@]}" --product TokeniBar
binary_dir=$(swift build "${swift_build_arguments[@]}" --show-bin-path)

if [[ "$app_dir" != "$output_dir"/* ]]; then
    print -u2 "Unexpected app output path: $app_dir"
    exit 1
fi

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_dir/TokeniBar" "$contents_dir/MacOS/TokeniBar"
cp -R "$binary_dir/TokeniBar_TokeniCore.bundle" "$contents_dir/Resources/TokeniBar_TokeniCore.bundle"
cp -R "$binary_dir/TokeniBar_TokeniBar.bundle" "$contents_dir/Resources/TokeniBar_TokeniBar.bundle"
cp -R "$binary_dir/TokeniBar_TokeniBar.bundle/BrandIcons" "$contents_dir/Resources/BrandIcons"
cp -R "$binary_dir/TokeniBar_TokeniBar.bundle/CompanionAssets" "$contents_dir/Resources/CompanionAssets"
cp "$project_dir/packaging/Info.plist" "$contents_dir/Info.plist"

icon_source="$project_dir/packaging/AppIcon.png"
iconset_dir="$output_dir/AppIcon.iconset"
if [[ ! -f "$icon_source" ]]; then
    print -u2 "Missing app icon source: $icon_source"
    exit 1
fi
if [[ "$iconset_dir" != "$output_dir"/* ]]; then
    print -u2 "Unexpected iconset output path: $iconset_dir"
    exit 1
fi
rm -rf "$iconset_dir"
mkdir -p "$iconset_dir"
for specification in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"
do
    size=${specification%% *}
    filename=${specification#* }
    sips -z "$size" "$size" "$icon_source" \
        --out "$iconset_dir/$filename" >/dev/null
done
iconutil -c icns "$iconset_dir" \
    -o "$contents_dir/Resources/AppIcon.icns"
rm -rf "$iconset_dir"

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
