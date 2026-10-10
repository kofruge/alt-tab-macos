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
# What: Configure keychain timeout and unlock for unattended headless CI operation.
# Why: Prevents macOS keychain from automatically locking during long compilation steps.
security set-keychain-settings -lut 21600 $keychain
security unlock-keychain -p $keychainPassword $keychain
# What: Import PKCS#12 identity into the dedicated CI keychain and grant access to codesign binary.
# Why: Explicitly specifying `-k $keychain` ensures import into the intended target keychain,
# and adding `codesign:` to the partition list prevents interactive authorization prompts.
security import $certificateFile.p12 -k $keychain -P "$certificatePassword" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k $keychainPassword $keychain > /dev/null
