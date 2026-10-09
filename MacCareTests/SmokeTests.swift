import XCTest
@testable import MacCare

final class SmokeTests: XCTestCase {
    func testStripANSI() {
        XCTAssertEqual(Proc.stripANSI("\u{1B}[32mhello\u{1B}[0m"), "hello")
    }
}
