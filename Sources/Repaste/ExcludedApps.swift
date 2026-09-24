import AppKit
import RepasteCore
import UniformTypeIdentifiers

/// Apps whose copies are never recorded, stored as bundle IDs in UserDefaults.
final class ExcludedApps: ObservableObject {
    static let defaultsKey = "excludedAppBundleIDs"

    @Published private(set) var bundleIDs: [String]
    /// Called after an app is added, so existing history from it can be purged.
    var onAdd: ((String) -> Void)?

    init() {
        bundleIDs = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? AppExclusions.defaultExcluded
    }

    func contains(_ bundleID: String) -> Bool {
        bundleIDs.contains(bundleID)
    }

    func add(_ bundleID: String) {
        guard !contains(bundleID) else { return }
        bundleIDs.append(bundleID)
        save()
        onAdd?(bundleID)
    }

    func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
        save()
    }

    /// Lets the user pick an app from /Applications and excludes it.
    func chooseAndAdd() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App to Exclude"
        panel.prompt = "Exclude"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let id = Bundle(url: url)?.bundleIdentifier { add(id) }
        }
    }

    private func save() {
        UserDefaults.standard.set(bundleIDs, forKey: Self.defaultsKey)
    }
}

/// Display name and icon for a bundle ID, falling back to the ID when the app is not installed.
struct AppInfo {
    let bundleID: String
    let name: String
    let icon: NSImage
    let isInstalled: Bool

    init(bundleID: String) {
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            icon = NSWorkspace.shared.icon(forFile: url.path)
            isInstalled = true
        } else {
            name = bundleID
            icon = NSWorkspace.shared.icon(for: .application)
            isInstalled = false
        }
    }
}
