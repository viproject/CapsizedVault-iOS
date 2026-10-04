# Changelog

All notable changes to CapsizedVault are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/).

## [1.1]

### Added
- **Custom nodes**: add your own Monero node with a URL, a trusted/untrusted flag, and an optional RPC login and password. Swipe a node to edit or delete it.
- **"Choose node automatically" toggle**: turn automatic selection off to keep the wallet on a node you pick. Choosing a node manually asks for confirmation before automatic selection is turned off.
- **Node testing**: test all nodes to see each one's latency and block height.
- **Node Settings shortcut**: when automatic selection is off and the connection fails, the sync card shows a **Node Settings** button.

### Changed
- **Improved node rotation**: nodes are ranked by live health (latency and block height). The wallet only moves to another node if it's clearly better (at least 25%) or the current node fails. Health checks run every minute while syncing and every 10 minutes once synced.
- Only built-in nodes are picked automatically. Custom nodes are used only when you choose them.

### Fixed
- The git commit hash is now written to the app's Info.plist in archive builds as well, so the version shown in Settings matches the release tag.

## [1.0]

### Added
- First public release: create wallets (16-word Polyseed or 25-word legacy seed) and restore them from a seed or spend/view keys
- Multiple wallets and Monero accounts
- Send and receive, with QR scanning and subaddresses
- Transaction history
- PIN and Face ID / Touch ID lock
- Live XMR price via CoinGecko

[1.1]: https://github.com/viproject/CapsizedVault-iOS/compare/v1.0...v1.1
[1.0]: https://github.com/viproject/CapsizedVault-iOS/releases/tag/v1.0
