import XCTest
@testable import MacCare

final class TreemapTests: XCTestCase {
    func testTilesFillRectProportionally() {
        let sizes: [Double] = [6, 6, 4, 3, 2, 2, 1]
        let rect = CGRect(x: 0, y: 0, width: 600, height: 400)
        let r = Treemap.layout(sizes, in: rect)
        XCTAssertEqual(r.count, sizes.count)
        let total = sizes.reduce(0, +)
        for (s, t) in zip(sizes, r) {
            XCTAssertEqual(Double(t.width * t.height), s / total * 240_000, accuracy: 1.0)
            XCTAssertTrue(rect.insetBy(dx: -0.01, dy: -0.01).contains(t))
        }
        XCTAssertEqual(r.reduce(0) { $0 + Double($1.width * $1.height) }, 240_000, accuracy: 2.0)
    }

    func testNoOverlap() {
        let r = Treemap.layout([50, 30, 20, 10, 5, 5, 1], in: CGRect(x: 0, y: 0, width: 300, height: 300))
        for i in 0..<r.count { for j in (i + 1)..<r.count {
            let inter = r[i].insetBy(dx: 0.05, dy: 0.05).intersection(r[j].insetBy(dx: 0.05, dy: 0.05))
            XCTAssertTrue(inter.isNull || inter.isEmpty, "\(i) overlaps \(j)")
        } }
    }

    func testEmptyAndSingle() {
        XCTAssertTrue(Treemap.layout([], in: CGRect(x: 0, y: 0, width: 10, height: 10)).isEmpty)
        XCTAssertEqual(Treemap.layout([5], in: CGRect(x: 0, y: 0, width: 10, height: 10)).first, CGRect(x: 0, y: 0, width: 10, height: 10))
    }
}
