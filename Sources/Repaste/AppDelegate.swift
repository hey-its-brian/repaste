import AppKit
import RepasteCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var store: HistoryStore!
    private let watcher = PasteboardWatcher()
    private let settingsWindow = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsDefaults.register()

        store = HistoryStore(fileURL: Self.historyFileURL, limit: currentLimit)

        watcher.onCopy = { [weak self] text, source in
            self?.store.add(text, sourceAppBundleID: source)
        }
        watcher.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(defaultsChanged),
            name: UserDefaults.didChangeNotification, object: nil)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Repaste")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private static var historyFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Repaste", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    private var currentLimit: Int {
        UserDefaults.standard.integer(forKey: SettingsKey.historyLimit)
    }

    @objc private func defaultsChanged() {
        if store.limit != currentLimit { store.limit = currentLimit }
    }

    // MARK: - Status item

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let wantsOptions = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        show(menu: wantsOptions ? optionsMenu() : historyMenu())
    }

    /// Attaching the menu only for the duration of the click keeps the button's own action
    /// working, so left and right clicks can open different menus.
    private func show(menu: NSMenu) {
        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // MARK: - Left click: history

    private func historyMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if isPasteboardAccessDenied {
            menu.addItem(disabledItem("Clipboard access is turned off for Repaste"))
            menu.addItem(actionItem("Open Privacy Settings…", #selector(openPasteboardPrivacySettings)))
            menu.addItem(.separator())
        }

        if store.entries.isEmpty {
            menu.addItem(disabledItem("No clipboard history yet"))
        }

        for (index, entry) in store.entries.enumerated() {
            // ⌘1 through ⌘9 are not needed: while a menu is open a bare digit selects the item.
            let key = index < 9 ? String(index + 1) : ""
            let title = ClipFormatting.menuTitle(for: entry.text)

            let paste = actionItem(title, #selector(pasteEntry(_:)), key: key)
            paste.keyEquivalentModifierMask = []
            paste.representedObject = entry.id
            paste.toolTip = String(entry.text.prefix(500))
            menu.addItem(paste)

            // Shown in place of the entry while ⌥ is held.
            let remove = actionItem("Remove “\(ClipFormatting.menuTitle(for: entry.text, maxLength: 50))”",
                                    #selector(removeEntry(_:)), key: key)
            remove.keyEquivalentModifierMask = .option
            remove.isAlternate = true
            remove.representedObject = entry.id
            menu.addItem(remove)
        }

        menu.addItem(.separator())
        let clear = actionItem("Clear All History…", #selector(clearAll))
        clear.isEnabled = !store.entries.isEmpty
        menu.addItem(clear)

        if !store.entries.isEmpty {
            menu.addItem(disabledItem("Hold ⌥ to remove an entry"))
        }
        return menu
    }

    @objc private func pasteEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let entry = store.entries.first(where: { $0.id == id }) else { return }
        watcher.write(entry.text)
        store.promote(id: id)
        if UserDefaults.standard.bool(forKey: SettingsKey.autoPaste) {
            AutoPaster.paste()
        }
    }

    @objc private func removeEntry(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        store.remove(id: id)
    }

    @objc private func clearAll() {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This removes all \(store.entries.count) saved entries. Your current clipboard is not changed."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.clear()
        }
    }

    // MARK: - Right click: options

    private func optionsMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem("Settings…", #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Repaste", #selector(quit), key: "q"))
        return menu
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Pasteboard privacy

    /// macOS 15.4+ lets users deny an app programmatic clipboard access.
    private var isPasteboardAccessDenied: Bool {
        if #available(macOS 15.4, *) {
            return NSPasteboard.general.accessBehavior == .alwaysDeny
        }
        return false
    }

    @objc private func openPasteboardPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Helpers

    private func actionItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
