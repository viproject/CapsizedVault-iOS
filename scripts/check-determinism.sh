#!/bin/bash
# Builds the unsigned Release .app twice — from the same checkout path and
# the same DerivedData path, wiped and rebuilt from scratch in between — and
# verifies the output is byte-for-byte identical. This is the hard gate for
# Phase 1 of REPRODUCIBLE_BUILDS.md.
#
# Why both paths are fixed, not just normalized: SwiftPM package dependencies
# (remote packages like GRDB, and our own submodule's local package) do not
# inherit the consuming project's OTHER_CFLAGS/OTHER_SWIFT_FLAGS, and their
# object files' N_OSO debug-map stabs are not rewritten by -oso_prefix either
# (both confirmed by direct build-log/nm inspection, not assumed) — these are
# genuine Xcode/SwiftPM/ld64 integration limits, not flag mistakes. So package
# code can still embed the real absolute checkout path and DerivedData path.
# Rather than fight that, REPRODUCIBLE_BUILDS.md requires CI and any verifier
# to use the identical canonical checkout path AND the identical
# -derivedDataPath — exactly what the original spec already called for. With
# both pinned, there is nothing left to normalize. Config/Deterministic.xcconfig
# (-oso_prefix, file-prefix-map on $(OBJROOT)) still helps for the app
# target's own object files as defense in depth, but is no longer load-bearing
# for this script's pass/fail result.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d /tmp/capsized-determinism-XXXXXX)"

cleanup() {
    local status=$?
    if [ "$status" -eq 0 ]; then
        rm -rf "$WORK"
    else
        echo "Build logs and checkout left for inspection at: $WORK" >&2
    fi
}
trap cleanup EXIT

COMMIT="$(git -C "$REPO_ROOT" rev-parse "${1:-HEAD}")"
echo "Checking determinism for commit $COMMIT"

CHECKOUT="$WORK/checkout"
DD="$WORK/dd"
ARCHIVE="$WORK/CapsizedVault.xcarchive"
ARTIFACTS="$WORK/artifacts"
mkdir -p "$ARTIFACTS"

git clone --quiet --no-local --recurse-submodules "$REPO_ROOT" "$CHECKOUT"
git -C "$CHECKOUT" checkout --quiet "$COMMIT"
git -C "$CHECKOUT" submodule update --init --recursive --quiet

# Uses the archive action, not build: release.yml signs via
# `xcodebuild -exportArchive`, which requires an .xcarchive as input (and is
# the only Apple-documented path to a correctly-structured App Store IPA —
# see REPRODUCIBLE_BUILDS.md). This re-proves determinism under archive
# specifically rather than assuming it carries over from the build action.
build_one() {
    local log="$1"
    if ! xcodebuild archive \
        -project "$CHECKOUT/CapsizedVault.xcodeproj" \
        -scheme CapsizedVault \
        -configuration Release \
        -destination 'generic/platform=iOS' \
        -archivePath "$ARCHIVE" \
        -derivedDataPath "$DD" \
        -clonedSourcePackagesDirPath "$CHECKOUT/.spm-checkouts" \
        -jobs 1 \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        ZERO_AR_DATE=1 \
        > "$log" 2>&1; then
        echo "error: build failed — see $log" >&2
        exit 1
    fi
}

echo "Building (pass A)..."
build_one "$WORK/build-a.log"
APP_SRC="$ARCHIVE/Products/Applications/CapsizedVault.app"
if [ ! -d "$APP_SRC" ]; then
    echo "error: could not locate built CapsizedVault.app after pass A" >&2
    exit 2
fi
cp -R "$APP_SRC" "$ARTIFACTS/A.app"

echo "Wiping DerivedData and archive, rebuilding from scratch (pass B)..."
rm -rf "$DD" "$ARCHIVE"
build_one "$WORK/build-b.log"

APP_A="$ARTIFACTS/A.app"
APP_B="$ARCHIVE/Products/Applications/CapsizedVault.app"

if [ ! -d "$APP_A" ] || [ ! -d "$APP_B" ]; then
    echo "error: could not locate built CapsizedVault.app in one of the archives" >&2
    exit 2
fi

python3 "$REPO_ROOT/scripts/compare-builds" "$APP_A" "$APP_B"
