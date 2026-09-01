# Contributing to CapsizedVault

## Reporting Bugs

Open an issue and include:

- iOS and Xcode version
- Device or simulator
- Steps to reproduce
- Expected vs actual behavior
- Any relevant screenshots or logs

Please search existing issues before opening a new one.

## Suggesting Features

Open an issue describing the feature and the problem it solves.

## Pull Requests

1. Fork the repository
2. Create a branch from `main` using a descriptive name:
   - Bug fixes: `fix/login-crash`
   - New features: `feat/export-wallet`
3. Make your changes, keeping the scope focused (one fix or feature per PR)
4. Build and verify your changes compile cleanly
5. Open a PR against `main` with:
   - A short title summarising the change
   - A description of what changed and why
   - Steps to reproduce (for bug fixes) or a usage example (for features)

## Code Style

Match the existing code style:

- 4-space indentation
- PascalCase for types, camelCase for properties and methods
- No force unwraps
- SwiftUI views with clear separation of concerns
- Prefer `async`/`await` over Combine

## License

By contributing, you agree your code will be licensed under the project's existing license.
