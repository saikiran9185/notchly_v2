#!/bin/bash
# Build NotchlyV2 macOS app with filtered output

cd "$(dirname "$0")/../.." || exit 1

if command -v xcpretty &> /dev/null; then
    xcodebuild -scheme NotchlyV2 -configuration Debug build 2>&1 | xcpretty
else
    xcodebuild -scheme NotchlyV2 -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD)"
fi
