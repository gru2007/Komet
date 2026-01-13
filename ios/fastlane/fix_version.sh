#!/bin/bash

# Script to fix version normalization from 1.0.0 to 1.0 in Info.plist
# This script should be run after Flutter build but before IPA creation
# It searches for Info.plist in common build locations and fixes the version

set -e

# Function to fix version in a given Info.plist
fix_version_in_plist() {
    local plist_path="$1"
    
    if [ ! -f "$plist_path" ]; then
        return 1
    fi
    
    echo "Checking: $plist_path"
    
    # Get current version
    local current_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path" 2>/dev/null || echo "")
    
    if [ -z "$current_version" ]; then
        return 1
    fi
    
    echo "  Current version: $current_version"
    
    # If version is 1.0.0, change it to 1.0
    if [ "$current_version" = "1.0.0" ]; then
        echo "  Changing version from 1.0.0 to 1.0"
        /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0" "$plist_path"
        echo "  ✓ Version fixed successfully in $plist_path"
        return 0
    else
        echo "  Version is already $current_version, no change needed"
        return 0
    fi
}

echo "Searching for Info.plist files to fix version..."

# List of possible locations for Info.plist
declare -a plist_locations=(
    "build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Info.plist"
    "build/ios/iphoneos/Runner.app/Info.plist"
    "build/ios/Release-iphoneos/Runner.app/Info.plist"
    "build/ios/Debug-iphoneos/Runner.app/Info.plist"
    "build/ios/Profile-iphoneos/Runner.app/Info.plist"
)

fixed_count=0

# Try to fix version in each location
for plist_path in "${plist_locations[@]}"; do
    if fix_version_in_plist "$plist_path"; then
        fixed_count=$((fixed_count + 1))
    fi
done

if [ $fixed_count -eq 0 ]; then
    echo "Warning: No Info.plist files found or fixed. This is normal if build hasn't completed yet."
    exit 0
else
    echo "Successfully fixed version in $fixed_count location(s)"
fi
