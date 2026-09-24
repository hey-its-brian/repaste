# Repaste To Do

## Planned

- [ ] **Per-app exclusion**: turn off history recording for specific apps (for example a password
  manager, banking app, or terminal). Each entry already stores `sourceAppBundleID`, the frontmost
  app at copy time, so the remaining work is:
  - A list of excluded bundle IDs in Settings, with an app picker (`NSOpenPanel` on /Applications)
    and a remove button per row
  - A check in `PasteboardWatcher.poll()` that skips copies whose source app is excluded
  - Optional: a "Remove existing entries from this app" action when an app is added
  - Optional: "Don't record from <frontmost app>" shortcut in the right-click menu

## Ideas

- [ ] Global hotkey to open the history menu at the cursor
- [ ] Search/filter field for long histories
- [ ] Pin entries so they are never trimmed
- [ ] Pause recording toggle in the right-click menu
- [ ] Support images and rich text, not just plain text
