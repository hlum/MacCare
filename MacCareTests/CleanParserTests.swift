import XCTest
@testable import MacCare

final class CleanParserTests: XCTestCase {
    private func fixture() throws -> String {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "clean-dry-run", withExtension: "txt"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testRealOutput() throws {
        let p = CleanParser.parse(try fixture())
        XCTAssertEqual(p.groups.first?.name, "User essentials")
        XCTAssertEqual(p.groups.map(\.name).prefix(3), ["User essentials", "App caches", "Browsers"])
        XCTAssertFalse(p.groups.contains { $0.name == "Cloud & Office" }, "'Nothing to clean' groups are dropped")
        XCTAssertTrue(p.needsSudoNote)
        XCTAssertEqual(try XCTUnwrap(p.potentialBytes), 2.52 * 1073741824, accuracy: 1e7)
    }

    func testAwkwardLines() {
        let p = CleanParser.parse("""
        ➤ Mixed
          → User app cache · 11 items, 1.86GB dry
          → Messages sticker cache · 0B dry
          → Trash · would empty, 11 items
          → Chrome Service Worker, would clean 51.0MB, 0 protected
          → npm cache · would clean
          → Homebrew cleanup · would free 156.5MB
            dav1d 1.5.3 · 940.1KB
          ⊙ Docker unused data · review with docker system df
        """)
        let items = p.groups[0].items
        XCTAssertEqual(items.count, 7, "sub-lines are not items")
        XCTAssertEqual(items[0].count, 11); XCTAssertEqual(try XCTUnwrap(items[0].bytes), 1.86 * 1073741824, accuracy: 1e6)
        XCTAssertEqual(items[1].bytes, 0)
        XCTAssertNil(items[2].bytes); XCTAssertEqual(items[2].count, 11)
        XCTAssertEqual(items[3].name, "Chrome Service Worker"); XCTAssertEqual(try XCTUnwrap(items[3].bytes), 51 * 1048576, accuracy: 1e5)
        XCTAssertNil(items[4].bytes)
        XCTAssertEqual(try XCTUnwrap(items[5].bytes), 156.5 * 1048576, accuracy: 1e5)
        XCTAssertTrue(items[6].reviewOnly); XCTAssertEqual(p.groups[0].bytes, items[0].bytes! + 0 + items[3].bytes! + items[5].bytes!, accuracy: 1)
    }
}
