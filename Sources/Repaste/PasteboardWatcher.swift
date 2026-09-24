import AppKit
import RepasteCore

/// Polls the general pasteboard for new text. macOS has no change notification for the
/// pasteboard, so polling `changeCount` is the standard approach and is very cheap.
final class PasteboardWatcher {
    var onCopy: ((_ text: String, _ sourceAppBundleID: String?) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        // Start from the current count so whatever was on the clipboard before launch is not read.
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
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

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let types = pasteboard.types?.map(\.rawValue) ?? []
        guard !ClipFormatting.shouldIgnore(types: types),
              let text = pasteboard.string(forType: .string) else { return }

        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard source != Bundle.main.bundleIdentifier else { return }
        onCopy?(text, source)
    }
}
