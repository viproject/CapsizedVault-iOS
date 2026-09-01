# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in CapsizedVault, please report it privately by emailing:

**security@capsized.io**

Include as much of the following as possible:

- Description of the vulnerability and its potential impact
- Steps to reproduce or proof-of-concept
- Affected version(s) or commit hash
- Any suggested mitigations, if known

You will receive an acknowledgement within **48 hours**. We aim to provide a status update within **7 days** and to release a fix within **90 days** depending on severity and complexity.

## Responsible Disclosure

We ask that you:

- Give us reasonable time to investigate and fix the issue before any public disclosure
- Avoid accessing, modifying, or deleting user data during research
- Do not perform denial-of-service attacks or spam

We will credit researchers who responsibly disclose vulnerabilities in the release notes, unless you prefer to remain anonymous.

## Scope

Areas of particular concern for this application:

- Wallet key material exposure (seed, spend key, view key)
- Keychain storage bypass or credential leakage
- Authentication (PIN / Face ID / Touch ID) bypass
- Transaction signing flaws
- Node communication vulnerabilities (MITM, data injection)

## Supported Versions

Only the latest release is actively maintained. We recommend always running the most recent version available on the App Store.
