# CapsizedVault

A self-custodial Monero wallet for iOS. No accounts, no servers, no tracking — your keys stay on your device.

## Features

- **Create wallets** — generate a new 16-word Polyseed or 25-word legacy Monero seed
- **Restore wallets** — import from Polyseed, legacy seed, or spend/view keys
- **Multiple wallets** — manage several wallets in one app
- **Accounts** — use Monero's built-in account system for separating funds
- **Send & receive** — QR code scanning for addresses, subaddress generation for privacy
- **Transaction history** — with amounts, timestamps, and confirmation status
- **PIN + Face ID / Touch ID** — local authentication, no cloud backup of credentials
- **XMR price** — live conversion via CoinGecko (no API key required)

## Requirements

- iOS 15.0+
- Xcode 15+
- Swift 5.9+

## Building from Source

CapsizedMoneroKit.Swift is included as a git submodule.

```sh
git clone --recursive https://github.com/viproject/CapsizedVault-iOS.git
cd CapsizedVault-iOS
open CapsizedVault.xcodeproj
```

Then select the **CapsizedVault** scheme and build (⌘B).

> **Note:** The first build will resolve Swift Package Manager dependencies automatically. This requires an internet connection.

> **Note:** The submodule is checked out at a pinned commit (detached HEAD) — this is expected. If you intend to make changes to `CapsizedMoneroKit.Swift`, switch it to a branch first:
> ```sh
> cd Modules/CapsizedMoneroKit.Swift
> git checkout main
> ```

**Simulator builds** work without any changes — no bundle ID or signing configuration is needed.

**Device builds** require you to use your own signing identity. In Xcode → Signing & Capabilities, enable *Automatically manage signing*, select your team, and change `PRODUCT_BUNDLE_IDENTIFIER` in `Config/Debug.xcconfig` to a bundle ID registered under your account (e.g. `com.yourname.capsizedvault.dev`).

## Build Verification

Each App Store release corresponds to a tagged commit in this repository. A GitHub Actions workflow builds the app from source on every push to `main`, every pull request, and every release tag — you can view the build logs in the [Actions tab](../../actions).

Full byte-for-byte reproducible builds are not possible on iOS because Apple's code signing modifies the final binary. The app displays its version and git commit hash in **Settings → (bottom of sheet)**, e.g. `v1.0.0 (a3f9c12)`, so you can inspect the exact source that was compiled directly in this repository.

Each release includes a `CapsizedVault.dSYM.zip` attached to the [GitHub Release](../../releases). Apple does not modify the compiled code (`__TEXT` segment) when re-signing for the App Store, so the dSYM produced from a given source tag deterministically matches the App Store binary. To verify:

1. Note the commit hash shown in the app's Settings sheet
2. Download `CapsizedVault.dSYM.zip` from the matching [GitHub Release](../../releases)
3. Download the App Store IPA using [iMazing](https://imazing.com) or Apple Configurator
4. Run `dwarfdump --uuid CapsizedVault.app.dSYM` and compare against `dwarfdump --uuid <path-to-app-binary>` extracted from the IPA — a matching UUID confirms the binary was compiled from that commit

## Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Monero engine | [CapsizedMoneroKit](Modules/CapsizedMoneroKit.Swift/) (git submodule) |
| App-side persistence | RealmSwift |
| Secure storage | iOS Keychain |
| Authentication | LocalAuthentication (Face ID / Touch ID) |

### Key managers

| File | Responsibility |
|------|---------------|
| `WalletManager.swift` | Wallet lifecycle — create, load, switch, remove |
| `XMRWallet.swift` | Wraps `CapsizedMoneroKit.Kit`; bridges delegate events to app state |
| `AuthManager.swift` | PIN and biometric lock/unlock, background privacy overlay |
| `KeychainHelper.swift` | Stores wallet passwords and PIN hash |
| `CoinPriceManager.swift` | Polls CoinGecko for XMR/fiat price |
| `AppUpdateManager.swift` | Checks `capsized.io/version.json` for available updates |

## Configuration

The xcconfig files (`Config/Debug.xcconfig`, `Beta.xcconfig`, `Release.xcconfig`) contain deployment-specific values you will need to change for your own fork:

| Key | Purpose |
|-----|---------|
| `PRODUCT_BUNDLE_IDENTIFIER` | Your app's bundle ID |

The privacy policy URL (`PrivacyPolicyURL` in `Info.plist`) is set as a literal string — update it to your own URL or remove the key to hide the link entirely.

## Privacy

CapsizedVault collects no personal data. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy.

- Wallet credentials are stored in the iOS Keychain only — never transmitted
- The camera is used exclusively for QR scanning; images are never stored or sent
- Your IP address is visible to the Monero node you connect to
- XMR price is fetched anonymously from CoinGecko
- No analytics SDKs, no crash reporters, no advertising frameworks

## Dependencies

### CapsizedMoneroKit (submodule)

| Package | License | Purpose |
|---------|---------|---------|
| monero_c (binary) | LGPL-3.0 | Compiled Monero core |
| polyseed | LGPL-3.0 | 16-word seed generation and validation |
| GRDB | MIT | SQLite storage inside the kit |
| HsToolKit | MIT | Networking and reachability utilities |
| HdWalletKit | MIT | BIP39 mnemonic support |
| ObjectMapper | MIT | JSON mapping |
| BigInt | MIT | Large integer arithmetic |

### Main app

| Package | License | Purpose |
|---------|---------|---------|
| RealmSwift | Apache 2.0 | App-side data persistence |

## Contributing

Bug reports, feature suggestions, and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. Please note our [Code of Conduct](CODE_OF_CONDUCT.md). To report a security vulnerability privately, see [SECURITY.md](SECURITY.md).

## License

MIT — see [LICENSE](LICENSE)

Third-party binary notices for the Monero engine — see [Modules/CapsizedMoneroKit.Swift/NOTICES](Modules/CapsizedMoneroKit.Swift/NOTICES)
