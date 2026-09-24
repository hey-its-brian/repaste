import Foundation

public struct ClipEntry: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var copiedAt: Date
    /// Bundle ID of the app that was frontmost when the text was copied.
    /// Recorded now so per-app exclusion (see TODO.md) can build on it later.
    public var sourceAppBundleID: String?

    public init(id: UUID = UUID(), text: String, copiedAt: Date = Date(), sourceAppBundleID: String? = nil) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
        self.sourceAppBundleID = sourceAppBundleID
    }
}

/// Most-recent-first clipboard history, capped at `limit` entries and persisted as JSON.
public final class HistoryStore {
    public static let limitRange = 1...200

    public private(set) var entries: [ClipEntry] = []
    public var onChange: (() -> Void)?

    public var limit: Int {
        didSet {
            limit = Self.clamp(limit)
            if trim() { changed() }
        }
    }

    private let fileURL: URL?

    /// Pass `nil` for `fileURL` to keep history in memory only.
    public init(fileURL: URL?, limit: Int) {
        self.fileURL = fileURL
        self.limit = Self.clamp(limit)
        load()
    }

    /// Adds text to the top of the history. Copying something already in the history moves it to
    /// the top instead of duplicating it. Returns false when the text was ignored (blank).
    @discardableResult
    public func add(_ text: String, sourceAppBundleID: String? = nil, date: Date = Date()) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if entries.first?.text == text { return false }
        entries.removeAll { $0.text == text }
        entries.insert(ClipEntry(text: text, copiedAt: date, sourceAppBundleID: sourceAppBundleID), at: 0)
        trim()
        changed()
        return true
    }

    /// Moves an entry to the top, used when it is repasted.
    public func promote(id: UUID, date: Date = Date()) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.copiedAt = date
        entries.insert(entry, at: 0)
        changed()
    }

    public func remove(id: UUID) {
        let before = entries.count
        entries.removeAll { $0.id == id }
        if entries.count != before { changed() }
    }

    /// Removes every entry copied from the given app. Returns how many were removed.
    @discardableResult
    public func removeAll(fromApp bundleID: String) -> Int {
        let before = entries.count
        entries.removeAll { $0.sourceAppBundleID == bundleID }
        let removed = before - entries.count
        if removed > 0 { changed() }
        return removed
    }

    public func clear() {
        guard !entries.isEmpty else { return }
        entries.removeAll()
        changed()
    }

    // MARK: - Private

    private static func clamp(_ value: Int) -> Int {
        min(max(value, limitRange.lowerBound), limitRange.upperBound)
    }

    @discardableResult
    private func trim() -> Bool {
        guard entries.count > limit else { return false }
        entries.removeLast(entries.count - limit)
        return true
    }

    private func changed() {
        save()
        onChange?()
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ClipEntry].self, from: data) else { return }
        entries = decoded
        if trim() { save() }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: fileURL, options: [.atomic, .completeFileProtection])
            // History can contain anything the user copied, so keep the file private to this user.
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            NSLog("Repaste: failed to save history: \(error)")
        }
    }
}
