import XCTest
@testable import MacCare

final class DeleteGuardTests: XCTestCase {
    let home = "/Users/tester"
    func ok(_ p: String, active: String? = nil) -> Bool { DeleteGuard.allowed(p, home: home, activeXcode: active, checkVolume: false) }

    func testAllowsKnownChildren() {
        XCTAssertTrue(ok("\(home)/Library/Developer/Xcode/DerivedData"))
        XCTAssertTrue(ok("\(home)/Library/Developer/Xcode/DerivedData/App-abc/Build"))
        XCTAssertTrue(ok("\(home)/Library/Caches/org.swift.swiftpm"))
        XCTAssertTrue(ok("\(home)/Library/Logs/CoreSimulator"))
        XCTAssertTrue(ok("/Applications/Xcode-beta.app"))
        XCTAssertTrue(ok("/Applications/Xcode_26.app"))
    }

    func testRefusesOutsideAndRoots() {
        XCTAssertFalse(ok("\(home)/Documents/thesis.pdf"))
        XCTAssertFalse(ok("\(home)"))
        XCTAssertFalse(ok("/"))
        XCTAssertFalse(ok("/System/Library"))
        XCTAssertFalse(ok("\(home)/Library/Developer"), "the root itself")
        XCTAssertFalse(ok("\(home)/Library/Developer/"), "the root with a slash")
        XCTAssertFalse(ok("\(home)/Library/Caches"))
        XCTAssertFalse(ok("/Applications/Safari.app"))
        XCTAssertFalse(ok("/Applications/Xcode.app/Contents"), "only whole bundles")
        XCTAssertFalse(ok("relative/path"))
    }

    func testRefusesTraversal() {
        XCTAssertFalse(ok("\(home)/Library/Developer/../Documents"))
        XCTAssertFalse(ok("\(home)/Library/Caches/../../Documents/x"))
        XCTAssertFalse(ok("\(home)/Library/Developer/Xcode/DerivedData/../../../../Documents"))
    }

    func testRefusesCoreDeviceAndActiveXcode() {
        XCTAssertFalse(ok("\(home)/Library/Developer/CoreDevice"))
        XCTAssertFalse(ok("\(home)/Library/Developer/CoreDevice/DeviceFS/abc"))
        XCTAssertFalse(ok("/Applications/Xcode.app", active: "/Applications/Xcode.app"))
        XCTAssertTrue(ok("/Applications/Xcode-beta.app", active: "/Applications/Xcode.app"))
        XCTAssertFalse(ok("/Applications/Xcode.app/Contents/Developer", active: "/Applications/Xcode.app"))
    }

    func testRemoveDeletesChildOnlyInsideAllowedTree() throws {
        // A real directory in the system temp dir is NOT an allowed root, so the guard must refuse it.
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("guard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        guard case .refused = DeleteGuard.remove(d.path) else { return XCTFail("temp dir should be refused") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: d.path))
        try FileManager.default.removeItem(at: d)
    }
}
