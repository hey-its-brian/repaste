# Repaste

A lightweight macOS menu bar clipboard history. It remembers the text you copy so you can
paste it again later. No Dock icon, no main window.

## Install

Requires an Apple Silicon Mac running macOS 14 or later.

1. Download the latest `Repaste-<version>.zip` from
   [Releases](https://github.com/hey-its-brian/repaste/releases/latest).
2. Unzip it and move **Repaste.app** to Applications.
3. Open it. Repaste is signed with a Developer ID and notarized by Apple, so macOS opens it
   after the usual "downloaded from the internet" confirmation; no Terminal commands needed.
4. If macOS asks whether Repaste can read the clipboard, choose **Allow**.

Upgrading from 1.0.0: that build used a different signature, so macOS treats 1.0.1 as a new
app. If you turned on auto-paste, grant Accessibility permission again (remove the old Repaste
entry in System Settings > Privacy & Security > Accessibility first). Your history and settings
carry over.

## Using it

- **Left click** the clipboard icon to see your recent copies, newest first.
  - Click an entry (or press its number, 1 to 9) to put it back on the clipboard, then ⌘V.
  - Hold **⌥ Option** to turn entries into "Remove" items and delete one.
  - **Clear All History…** removes everything (asks first).
- **Right click** (or Control-click) the icon for **Settings…**, **Quit**, and
  **Don't Record from <app>** to exclude whatever app you are using right now.

## Settings

- **Entries to keep**: how many copies the menu shows and stores (1 to 200, default 20).
- **Paste automatically**: after choosing an entry, Repaste sends ⌘V to the app you were in.
  This needs Accessibility permission (System Settings > Privacy & Security > Accessibility).
- **Excluded Apps**: copies made while these apps are in front are never recorded. Adding an
  app also deletes any entries already copied from it. Remove an app with its minus button.
- **Launch at login**: works when Repaste is in /Applications.

## Privacy

- Copies marked concealed or transient (the nspasteboard.org convention used by 1Password,
  Bitwarden, Keychain Access and others) are never recorded.
- Common password managers are excluded by default: 1Password, Apple Passwords, Keychain
  Access, Bitwarden, KeePassXC and LastPass. This also covers usernames, notes and one-time
  codes, which these apps do not always mark as concealed.
- The clipboard does not record which app wrote to it, so Repaste checks every app that was
  in front since its last check (twice a second). Copying in an excluded app and quickly
  switching away still gets skipped. The limit: a floating panel that copies without coming to
  the front (such as a quick-access popup) looks like the app behind it. Password managers mark
  copied passwords as concealed, which covers that case.
- History is stored as plain JSON at `~/Library/Application Support/Repaste/history.json`
  with owner-only permissions (0600). Clear it from the menu at any time.
- On recent macOS versions the system may ask once whether Repaste can read the clipboard;
  choose **Allow**. If you deny it, the menu shows a shortcut to the privacy setting.

## Building

Requires Xcode (the Command Line Tools alone lack SwiftUI's macro plugin).

```bash
./scripts/build-app.sh            # builds build/Repaste.app for local use
./scripts/build-app.sh --install  # also copies it to /Applications
swift test                        # runs the RepasteCore unit tests
./scripts/release.sh              # signed, notarized zip in build/release
```

Local builds are signed with your Apple Development identity when one exists, so
Accessibility permission survives rebuilds (ad hoc otherwise).

### Releases

`scripts/release.sh` builds the app, signs it with the Developer ID Application certificate
for team L6X8U2TQ6F (hardened runtime, secure timestamp), submits it to Apple's notary
service, staples the ticket, and zips it. It prints the SHA-256 for the release notes.

One-time setup: install the Developer ID Application certificate in your login keychain, then
save notary credentials (it prompts for an app-specific password from account.apple.com):

```bash
xcrun notarytool store-credentials repaste-notary --apple-id <your Apple ID> --team-id L6X8U2TQ6F
```

Set `NOTARY_PROFILE=<name>` to use credentials saved under a different profile name. The
version number lives at the top of `scripts/build-app.sh`.

## Roadmap

See [TODO.md](TODO.md).
