# Reproducible builds

CapsizedVault's release pipeline (`.github/workflows/release.yml`) is designed so
that each link in the chain from source code to the signed binary in your hands
can be independently checked. This document explains exactly what that proves,
what it doesn't, and how to check it yourself.

## What is proven

1. **Source → unsigned build.** Rebuilding commit `X` under the pinned toolchain
   described below produces a byte-for-byte identical unsigned `.app` to the one
   CI produced for that tag. Verified by `scripts/compare-builds`.
2. **Unsigned → signed.** The signed IPA uploaded to App Store Connect for a
   release is exactly the published unsigned build plus code signatures. Only
   the signature, header size fields, and `__LINKEDIT` differ — `__TEXT`,
   `__DATA`, `LC_UUID`, and every other file in the bundle are identical.
   Verified by `scripts/verify-signed-vs-unsigned`.
3. **Signed IPA → GitHub Actions.** Both the unsigned build and the signed IPA
   carry a [GitHub artifact attestation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds),
   cryptographically tying the file to the exact workflow run, commit, and
   repository that produced it.

## What is **not** proven

The binary Apple actually serves to users through the App Store is
**FairPlay-encrypted**. There is no way, from outside Apple, to decrypt that
binary and diff it against our build — this is a deliberate Apple DRM
mechanism, not a gap in our process. The closest available check is comparing
`LC_UUID` (see "Cross-checking against the App Store binary" below), since that
load command sits outside the encrypted region. A UUID match tells you the App
Store binary was built from the same compilation as ours; it is not a
byte-for-byte diff of the encrypted payload.

## Toolchain requirements

Reproducing a build requires the **exact** toolchain CI used, not just a
similar one — different Xcode/Swift/Clang versions legitimately produce
different bytes from identical source.

| Component | Required version |
|---|---|
| Xcode | 27.0, build `27A266a` |
| macOS | 27.0.x (the exact point release only affects `BuildMachineOSBuild`, which both sides should expect to differ — see below) |
| Runner lineage | GitHub-hosted `xcode-27` image (currently **Preview** status) |

Check your installed Xcode build number with:
```sh
xcodebuild -version
```

`BuildMachineOSBuild` in the binary's metadata is expected to differ slightly
between CI's exact macOS point release and yours — this is normal and doesn't
affect determinism of the actual code. Everything else should match exactly.

## Fixed-path requirements

Two absolute paths must match **exactly** between CI and anyone verifying a
build — not just be internally consistent. This isn't a stylistic preference;
without it, verification genuinely fails. Here's why:

Xcode's build system does not propagate the consuming project's
`OTHER_CFLAGS`/`OTHER_SWIFT_FLAGS` into SwiftPM package dependency targets —
confirmed by inspecting the actual compiler invocations in a build log, not
assumed. That means the path-normalization flags in
`CapsizedVault/Config/Deterministic.xcconfig` only cover this project's own
code; a package dependency's compiled object code (GRDB, the submodule, etc.)
can still embed the literal absolute path it was built from, because of
unguarded `__FILE__`/`assert()` usage in that dependency's own source. Rather
than fight that (it would mean patching every dependency, including ones we
don't control), CI and any verifier simply use the same two paths, so there's
nothing left to differ:

1. **Checkout path**: `/Users/runner/work/CapsizedVault-iOS/CapsizedVault-iOS`
   — this is GitHub Actions' own default `$GITHUB_WORKSPACE` convention for
   this repo name, so CI needs no special configuration for it; you have to
   create it explicitly:
   ```sh
   sudo mkdir -p /Users/runner/work/CapsizedVault-iOS
   sudo chown "$(whoami)" /Users/runner/work/CapsizedVault-iOS
   git clone --recurse-submodules \
     https://github.com/viproject/CapsizedVault-iOS.git \
     /Users/runner/work/CapsizedVault-iOS/CapsizedVault-iOS
   cd /Users/runner/work/CapsizedVault-iOS/CapsizedVault-iOS
   git checkout <tag>
   ```
2. **DerivedData path**: `<checkout>/.build-dd`, passed via `-derivedDataPath`.
   This one matters for a different reason — some package object files' debug
   symbol-table entries (`N_OSO` stabs) aren't rewritten by the `-oso_prefix`
   linker flag we use for our own code, so they still embed the real
   `-derivedDataPath`. Same fix: match it exactly instead of trying to
   normalize it away.

   Also pass `-clonedSourcePackagesDirPath <checkout>/.spm-checkouts` — Xcode
   resolves SwiftPM package checkouts relative to `-derivedDataPath` by
   default, which would silently reintroduce the same DerivedData-path
   dependency inside package source files unless pinned separately.

If you skip either of these, the rebuild will very likely still *work* — it
just won't match CI's bytes, because the paths differ, not because anything
is actually non-deterministic.

## Rebuild-and-verify instructions

1. Set up the exact toolchain and both fixed paths above.
2. Build exactly as CI does — either run `scripts/check-determinism.sh` (which
   does this automatically, building twice to prove it), or build once
   manually:
   ```sh
   xcodebuild build \
     -project CapsizedVault.xcodeproj \
     -scheme CapsizedVault \
     -configuration Release \
     -destination 'generic/platform=iOS' \
     -derivedDataPath "$PWD/.build-dd" \
     -clonedSourcePackagesDirPath "$PWD/.spm-checkouts" \
     -jobs 1 \
     CODE_SIGN_IDENTITY="" \
     CODE_SIGNING_REQUIRED=NO \
     CODE_SIGNING_ALLOWED=NO
   ```
   `-jobs 1` (serial build) is required, not optional — parallel linking
   produces non-deterministic ObjC stub-table ordering in RealmSwift.framework
   specifically; this was confirmed empirically, not assumed.
   `ZERO_AR_DATE=1` should also be set in your shell environment.
3. Download all the files attached to the matching [GitHub Release](../../releases)
   into one directory — `SHA256SUMS` lists checksums for
   `CapsizedVault-unsigned.zip`, `CapsizedVault-dSYMs.zip`, `uuids.txt`, and
   `toolchain.txt` together, and `shasum -c` reports a (misleading) failure
   for any listed file it can't find on disk, not just the ones you changed.
4. Compare:
   ```sh
   shasum -a 256 -c SHA256SUMS
   ```
   or, to check just the one zip against its line in that file:
   ```sh
   grep CapsizedVault-unsigned.zip SHA256SUMS | shasum -a 256 -c -
   ```
   For a more precise diff (including which Mach-O segment differs, if
   anything does):
   ```sh
   unzip CapsizedVault-unsigned.zip -d theirs
   python3 scripts/compare-builds \
     .build-dd/Build/Products/Release-iphoneos/CapsizedVault.app \
     theirs/CapsizedVault.app
   ```

## Verifying unsigned vs. signed

If you have both the published unsigned build and a signed IPA for the same
release:
```sh
python3 scripts/verify-signed-vs-unsigned \
  .build-dd/Build/Products/Release-iphoneos/CapsizedVault.app \
  CapsizedVault.ipa
```
This checks every Mach-O in the bundle (main app plus embedded frameworks)
segment-by-segment, and every other file byte-for-byte, allowing only
`_CodeSignature/` and `embedded.mobileprovision` to differ.

## Verifying attestations

Each release's unsigned build and signed IPA carry a GitHub attestation. Since
this repository is public, verification works without authentication:
```sh
gh attestation verify CapsizedVault-unsigned.zip --repo viproject/CapsizedVault-iOS
gh attestation verify CapsizedVault.ipa --repo viproject/CapsizedVault-iOS
```
A successful result confirms the file was produced by a specific workflow run
in this repository, from a specific commit — not tampered with or substituted
after the fact.

## Reading LC_UUIDs

Every Mach-O file (an app executable, or a file inside a `.framework`) carries
an `LC_UUID` load command — a fingerprint of that specific compilation. List
every UUID in a bundle with:
```sh
python3 scripts/print-uuids path/to/CapsizedVault.app
```
or for a single file:
```sh
dwarfdump --uuid path/to/CapsizedVault
```

### Cross-checking against the App Store binary

Because the App Store binary is FairPlay-encrypted (see above), you can't diff
it directly — but its `LC_UUID` load command sits outside the encrypted
region, so `dwarfdump` can still read it:

1. Note the version/commit you want to check (the app shows this in
   **Settings → bottom of sheet**, e.g. `v1.2 (a3f9c12)`).
2. Download that release's dSYM(s) from the GitHub Release
   (`CapsizedVault-dSYMs.zip`) and unzip.
3. Extract the app binary from a real App Store IPA — e.g. via
   [iMazing](https://imazing.com) (Manage Apps → Library → select the app →
   Export .IPA) or Apple Configurator — and unzip it; the binary is at
   `Payload/CapsizedVault.app/CapsizedVault`.
4. Compare:
   ```sh
   dwarfdump --uuid CapsizedVault.app.dSYM
   dwarfdump --uuid Payload/CapsizedVault.app/CapsizedVault
   ```
   If the `arm64` UUIDs match, the App Store binary was compiled from that
   exact source — this is the strongest check possible against an encrypted
   binary, but it is a UUID match, not a byte-for-byte diff.
