#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <Tokeni Bar.app>" >&2
    exit 2
fi

app=$1
if [[ -z "$app" || "$app" == "/" || "${app##*.}" != "app" ]]; then
    echo "Refusing invalid application bundle path" >&2
    exit 2
fi

executable="$app/Contents/MacOS/TokeniBar"
if [[ ! -x "$executable" ]]; then
    echo "Packaged application executable is missing" >&2
    exit 1
fi

output=$("$executable" --smoke-test)
if [[ "$output" != "TOKENI_MACOS_PACKAGE_SMOKE_OK" ]]; then
    echo "Packaged application smoke test returned an unexpected result" >&2
    exit 1
fi

echo "$output"
