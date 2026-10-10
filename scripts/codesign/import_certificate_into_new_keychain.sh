#!/usr/bin/env bash

set -exu

certificateFile="$1"
certificatePassword="$2"

keychain="alt-tab-macos.keychain"
keychainPassword="password"

# create a keychain
security create-keychain -p $keychainPassword $keychain
# make keychain default so xcodebuild uses it
security default-keychain -s $keychain
# What: Appends the newly created keychain to the active user keychain search list.
# Why: `codesign` and `security find-identity` only query keychains listed in the search list;
# setting default alone is insufficient on headless CI runners.
security list-keychains -d user -s $keychain $(security list-keychains -d user 2>/dev/null | tr -d '"' || true)
# unlock keychain
security unlock-keychain -p $keychainPassword $keychain
# import p12 into Keychain
security import $certificateFile.p12 -P "$certificatePassword" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k $keychainPassword $keychain > /dev/null
