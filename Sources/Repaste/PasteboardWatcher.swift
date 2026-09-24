import AppKit
import RepasteCore

/// Polls the general pasteboard for new text. macOS has no change notification for the
/// pasteboard, so polling `changeCount` is the standard approach and is very cheap.
final class PasteboardWatcher {
    var onCopy: ((_ text: String, _ sourceAppBundleID: String?) -> Void)?
    /// Asked before reading a new copy; return true to leave it out of the history.
    var shouldSkipApps: ((Set<String>) -> Bool)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    /// Every app that was frontmost at some point since the previous poll. The pasteboard does not
    /// say who wrote to it, so any of these could be the source of a new copy.
    private var recentApps: Set<String> = []

    init() {
        // Start from the current count so whatever was on the clipboard before launch is not read.
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        noteFrontmostApp()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Writes text to the pasteboard without recording it as a new copy.
    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        if let id = app?.bundleIdentifier { recentApps.insert(id) }
    }

    private func noteFrontmostApp() {
        if let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { recentApps.insert(id) }
    }

    private func poll() {
        noteFrontmostApp()
        let candidates = recentApps
        // Carry the current frontmost app into the next window; it may be the next copy's source.
        recentApps = []
        noteFrontmostApp()

        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Checked before reading the contents, so text from an excluded app is never even loaded.
        if shouldSkipApps?(candidates) == true { return }

        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard !ClipFormatting.shouldIgnore(types: types),
              let text = pasteboard.string(forType: .string) else { return }

        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard source != Bundle.main.bundleIdentifier else { return }
        onCopy?(text, source)
    }
}
