<div align="center">

# Capsized Vault

A self-custodial Monero wallet for iOS. No accounts, no servers, no tracking — your keys stay on your device.

<a href="https://apps.apple.com/app/id6807507582"><img src=".github/assets/app-store-badge.svg" alt="Download on the App Store" height="48"></a>

Follow updates on X: [@Capsizedvault](https://x.com/Capsizedvault)

</div>

## Features

- **Create wallets** — generate a new 16-word Polyseed or 25-word legacy Monero seed
- **Restore wallets** — import from Polyseed, legacy seed, or spend/view keys, or add a view-only wallet from an address and view key
- **Multiple wallets** — manage several wallets in one app
- **Accounts** — use Monero's built-in account system for separating funds
- **Send & receive** — QR code scanning for addresses, subaddress generation for privacy
- **Transaction history** — with amounts, timestamps, and confirmation status
- **PIN + Face ID / Touch ID** — local authentication, no cloud backup of credentials
- **XMR price** — live conversion via CoinGecko (no API key required)
- **Node management** — built-in default nodes with automatic selection and adaptive failover, or add your own node (with optional RPC login) and pin the wallet to it

See [CHANGELOG.md](CHANGELOG.md) for release history.

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

Each App Store release corresponds to a tagged commit in this repository, built and signed by a GitHub Actions workflow you can inspect in the [Actions tab](../../actions). Source rebuilds are verified byte-for-byte deterministic, and the signed IPA is verified to be exactly that unsigned build plus code signatures — see [REPRODUCIBLE_BUILDS.md](REPRODUCIBLE_BUILDS.md) for exactly what's proven, what isn't (the FairPlay-encrypted App Store binary itself is out of reach, by design), and step-by-step instructions to verify a release yourself.

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
| `XMRWallet.swift` | Wraps `CapsizedMoneroKit.Kit`; bridges delegate events to app state; node selection and switching |
| `AuthManager.swift` | PIN and biometric lock/unlock, background privacy overlay |
| `KeychainHelper.swift` | Stores wallet passwords, PIN hash, and custom node RPC credentials |
| `CoinPriceManager.swift` | Polls CoinGecko for XMR/fiat price |
| `AppUpdateManager.swift` | Checks `capsized.io/version.json` for available updates |
| `RealmManager.swift` | Wallet metadata, cached balances, custom node list |

## Configuration

The xcconfig files (`Config/Debug.xcconfig`, `Beta.xcconfig`, `Release.xcconfig`) contain deployment-specific values you will need to change for your own fork:

| Key | Purpose |
|-----|---------|
| `PRODUCT_BUNDLE_IDENTIFIER` | Your app's bundle ID |

The privacy policy URL (`PrivacyPolicyURL` in `Info.plist`) is set as a literal string — update it to your own URL or remove the key to hide the link entirely.

## Privacy

CapsizedVault collects no personal data. See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy.

- Wallet credentials are stored in the iOS Keychain only — never transmitted
- Custom node login/password are stored in the iOS Keychain only
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
