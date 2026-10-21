# Release setup (for maintainers)

This document covers the one-time setup needed before `.github/workflows/release.yml`
can sign and upload a release. It assumes you've read
[REPRODUCIBLE_BUILDS.md](../REPRODUCIBLE_BUILDS.md) for the "why" behind the
build job; this is about the `sign` job specifically.

## Cutting a release

Each tag push produces one build with one unique build number. To ship a new
build — including a resubmission under the **same** marketing version — do
this every time:

1. **Bump `CURRENT_PROJECT_VERSION`** (the build number, e.g. `15` → `16`).
   Leave `MARKETING_VERSION` (e.g. `1.2`) unchanged unless you're actually
   releasing a new version. This is a project-level build setting in Xcode
   (select the project, not the target → Build Settings → Versioning →
   Current Project Version) — Apple rejects an upload whose build number
   isn't strictly greater than every previous upload for that app, even
   under an unchanged marketing version.
2. **Commit** that change.
3. **Push a new tag** matching `v*` that you haven't used before (e.g.
   `v1.2-2` for a second build of version `1.2`). Don't force-push or reuse
   an old tag name — each tag is meant to map to exactly one build, which is
   what makes the provenance story in REPRODUCIBLE_BUILDS.md meaningful.
4. The `build` job runs automatically. When it finishes, approve the `sign`
   job in the repo's **Actions** tab (required reviewer gate on the
   `release` environment — see below). It signs, verifies, and uploads the
   new build to App Store Connect under the same marketing version.
5. Submitting the new build for App Review (or releasing it) is still a
   separate, manual step in App Store Connect, with Apple's own 2FA — this
   pipeline only uploads.

Expect one GitHub Release per tag, so a resubmission under the same version
gets its own release entry rather than editing a previous one in place.

## Required secrets

Set these under repo Settings → Secrets and variables → Actions:

| Secret | Purpose |
|---|---|
| `APPLE_DISTRIBUTION_CERTIFICATE_P12` | base64-encoded CI distribution certificate (`.p12`) |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | password for that `.p12` |
| `APPLE_PROVISIONING_PROFILE` | base64-encoded App Store distribution profile for `io.capsized.vault` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_P8` | App Store Connect API private key (raw `.p8` contents, including the `BEGIN/END PRIVATE KEY` lines) |

The signing keychain's own password isn't a secret here — `release.yml`
generates one at runtime with `openssl rand` and masks it, so it never needs
storing or rotating.

## Creating the `release` environment

In repo Settings → Environments → New environment, name it `release`, then:

- **Required reviewers**: add `viproject`. This pauses the `sign` job after
  `build` succeeds until a human approves it in the Actions tab — see the
  job's own comment in `release.yml` for why this matters (the `sign` job is
  the one with signing secrets and App Store Connect access).
- **Deployment branches and tags**: restrict to "Selected branches and tags"
  and add the tag pattern `v*`. This is a second, independent layer — even an
  approved run can't be triggered from an arbitrary branch.

Neither setting is expressible in the workflow YAML itself, which is why this
is a one-time manual step rather than something version-controlled.

## Creating the CI distribution certificate

Use a certificate **dedicated to CI** — don't reuse your personal development
certificate. If this certificate is ever compromised, you can revoke it
without affecting your own ability to sign locally.

1. [Apple Developer → Certificates](https://developer.apple.com/account/resources/certificates/list):
   create a new **Apple Distribution** certificate.
2. Generate the CSR in Keychain Access (Certificate Assistant → Request a
   Certificate from a Certificate Authority), upload it, download the
   resulting `.cer`.
3. Import the `.cer` into Keychain Access (it pairs with the private key from
   the CSR), then export **both** as one `.p12` (right-click the cert →
   Export → "Personal Information Exchange (.p12)"). Set a strong password on
   export — that becomes `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`.

## Creating the provisioning profile

[Apple Developer → Profiles](https://developer.apple.com/account/resources/profiles/list):
create a new profile, type **App Store**, App ID `io.capsized.vault`, signed
with the CI distribution certificate from above. Download the
`.mobileprovision` file.

## Creating the App Store Connect API key

[App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api):

1. Generate a key named something identifiable, e.g. `CapsizedVault CI`.
2. **Role: `Developer`** — the lowest role that can upload a build via the
   API. It cannot submit for review, change pricing, or touch metadata, which
   keeps submission/release a manual, 2FA-gated step as intended.
3. **Download the `.p8` immediately** — Apple only allows this once. Back it
   up somewhere secure before it disappears from the UI.
4. Note the Key ID and Issuer ID shown on the same page.

## Encoding secrets for GitHub

```sh
base64 -i CI_Distribution.p12 | pbcopy    # -> APPLE_DISTRIBUTION_CERTIFICATE_P12
base64 -i CapsizedVault_AppStore.mobileprovision | pbcopy    # -> APPLE_PROVISIONING_PROFILE
```
Paste directly from the clipboard into each secret's value field. The `.p8`
key doesn't need base64 encoding — paste its raw text contents (GitHub
secrets handle multiline values fine).

Delete the local `.p12`/`.mobileprovision`/`.p8` files once they're stored as
secrets — don't leave them sitting in a Downloads folder.

## Rotating or revoking

If the CI distribution certificate or the App Store Connect API key is ever
suspected to be compromised:

1. **Apple Developer portal**: revoke the certificate (Certificates →
   select it → Revoke) and/or delete the API key (App Store Connect →
   Integrations → select it → Delete).
2. Generate replacements following the steps above.
3. Update the corresponding GitHub secret(s) by name — no code or workflow
   changes are needed, since `release.yml` only ever references secrets by
   name, never embeds their values.
4. If the provisioning profile referenced the revoked certificate, regenerate
   it too (a profile becomes invalid when its signing certificate is
   revoked).

Revoking the CI certificate has no effect on your personal development
certificate, since they're deliberately separate — this is the entire reason
for keeping them separate in the first place.
