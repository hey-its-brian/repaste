import AppKit
import ApplicationServices

/// Sends ⌘V to the frontmost app. Posting keyboard events needs Accessibility permission.
enum AutoPaster {
    private static let vKeyCode: CGKeyCode = 9 // kVK_ANSI_V, layout independent

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func paste() {
        guard isTrusted else { return }
        // Give the menu time to close so focus is back in the previous app before the keystroke.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
