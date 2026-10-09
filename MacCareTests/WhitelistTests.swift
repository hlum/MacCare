import XCTest
@testable import MacCare

final class WhitelistTests: XCTestCase {
    private func tmp() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("wl-\(UUID().uuidString)") }

    func testNoOriginalCreatesThenRemoves() throws {
        let u = tmp()
        let restore = CleanStore.installTemp(["/a/b"], core: ["/core/1", "/core/2"], at: u)
        let text = try String(contentsOf: u, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("/core/1\n/core/2\n"), "mo's defaults must be carried over when we create the file")
        XCTAssertTrue(text.contains("# maccare-temp-begin\n/a/b\n# maccare-temp-end"))
        restore()
        XCTAssertFalse(FileManager.default.fileExists(atPath: u.path))
    }

    func testOriginalRestoredByteForByte() throws {
        let u = tmp()
        let original = Data("/mine/one\n# a comment\n/mine/two".utf8)   // note: no trailing newline
        try original.write(to: u)
        let restore = CleanStore.installTemp(["/x"], core: ["/core"], at: u)
        let during = try String(contentsOf: u, encoding: .utf8)
        XCTAssertTrue(during.hasPrefix("/mine/one"))
        XCTAssertFalse(during.contains("/core"), "an existing user file must not be padded with defaults")
        restore()
        XCTAssertEqual(try Data(contentsOf: u), original)
    }

    func testRecoveryStripsLeftoverBlock() throws {
        let u = tmp()
        try "/keep\n# maccare-temp-begin\n/gone\n# maccare-temp-end\n/keep2".write(to: u, atomically: true, encoding: .utf8)
        CleanStore.recoverLeftoverWhitelist(at: u)
        XCTAssertEqual(try String(contentsOf: u, encoding: .utf8), "/keep\n/keep2")
    }

    func testGroupPathsParse() {
        let p = CleanStore.readGroupPaths()   // reads the real clean-list if present; just must not crash
        XCTAssertNotNil(p)
    }
}
