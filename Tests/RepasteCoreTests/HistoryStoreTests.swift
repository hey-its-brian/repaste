import XCTest
@testable import RepasteCore

final class HistoryStoreTests: XCTestCase {
    func testAddPutsNewestFirst() {
        let store = HistoryStore(fileURL: nil, limit: 10)
        store.add("one")
        store.add("two")
        XCTAssertEqual(store.entries.map(\.text), ["two", "one"])
    }

    func testBlankTextIsIgnored() {
        let store = HistoryStore(fileURL: nil, limit: 10)
        XCTAssertFalse(store.add("   \n\t"))
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testDuplicateMovesToTop() {
        let store = HistoryStore(fileURL: nil, limit: 10)
        store.add("a")
        store.add("b")
        store.add("a")
        XCTAssertEqual(store.entries.map(\.text), ["a", "b"])
    }

    func testLimitTrimsOldest() {
        let store = HistoryStore(fileURL: nil, limit: 3)
        ["1", "2", "3", "4"].forEach { store.add($0) }
        XCTAssertEqual(store.entries.map(\.text), ["4", "3", "2"])
    }

    func testLoweringLimitTrims() {
        let store = HistoryStore(fileURL: nil, limit: 5)
        ["1", "2", "3", "4"].forEach { store.add($0) }
        store.limit = 2
        XCTAssertEqual(store.entries.map(\.text), ["4", "3"])
    }

    func testLimitIsClamped() {
        let store = HistoryStore(fileURL: nil, limit: 0)
        XCTAssertEqual(store.limit, 1)
        store.limit = 10_000
        XCTAssertEqual(store.limit, HistoryStore.limitRange.upperBound)
    }

    func testPromoteAndRemove() {
        let store = HistoryStore(fileURL: nil, limit: 10)
        ["a", "b", "c"].forEach { store.add($0) }
        let a = store.entries.last!
        store.promote(id: a.id)
        XCTAssertEqual(store.entries.map(\.text), ["a", "c", "b"])
        store.remove(id: a.id)
        XCTAssertEqual(store.entries.map(\.text), ["c", "b"])
    }

    func testClear() {
        let store = HistoryStore(fileURL: nil, limit: 10)
        store.add("a")
        var notified = false
        store.onChange = { notified = true }
        store.clear()
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(notified)
    }

    func testPersistsAcrossInstances() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let first = HistoryStore(fileURL: url, limit: 10)
        first.add("kept", sourceAppBundleID: "com.apple.Safari")
        first.add("newest")

        let second = HistoryStore(fileURL: url, limit: 10)
        XCTAssertEqual(second.entries.map(\.text), ["newest", "kept"])
        XCTAssertEqual(second.entries.last?.sourceAppBundleID, "com.apple.Safari")

        let perms = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }

    func testConcealedTypesAreIgnored() {
        XCTAssertTrue(ClipFormatting.shouldIgnore(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
        XCTAssertFalse(ClipFormatting.shouldIgnore(types: ["public.utf8-plain-text"]))
    }

    func testMenuTitleCollapsesAndTruncates() {
        XCTAssertEqual(ClipFormatting.menuTitle(for: "  hello\n\n  world  "), "hello world")
        let long = String(repeating: "x", count: 100)
        let title = ClipFormatting.menuTitle(for: long, maxLength: 10)
        XCTAssertEqual(title.count, 10)
        XCTAssertTrue(title.hasSuffix("…"))
    }
}
