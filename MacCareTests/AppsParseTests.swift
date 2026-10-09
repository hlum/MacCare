import XCTest
@testable import MacCare

final class AppsParseTests: XCTestCase {
    func testParsesFileList() {
        let out = """
        Files to be removed:
        ◎ Arduino IDE , 547.6MB
          ✓ /Applications/Arduino IDE.app , 544.4MB
          ✓ ~/Library/Preferences/cc.arduino.IDE2.plist , 4KB
          ✓ ~/Library/Preferences/ByHost/cc.arduino.IDE2.ShipIt.0B02581B.plist , 4KB
        ➤ Remove 1 app, 547.6MB  Enter confirm, ESC cancel:
        """
        let f = AppsStore.parseFiles(out)
        XCTAssertEqual(f.count, 3)
        XCTAssertEqual(f[0].path, "/Applications/Arduino IDE.app")
        XCTAssertEqual(f[0].bytes, 544.4 * 1048576, accuracy: 1e5)
        XCTAssertEqual(f[1].bytes, 4096)
    }

    func testDecodesUninstallList() throws {
        let json = #"[{"name": "Steam", "bundle_id": "com.valvesoftware.steam", "source": "App", "uninstall_name": "Steam", "path": "/Applications/Steam.app", "size": "12.3MB"}]"#
        let apps = try Mo.decoder.decode([InstalledApp].self, from: Data(json.utf8))
        XCTAssertEqual(apps[0].uninstallName, "Steam"); XCTAssertEqual(apps[0].bytes, 12.3 * 1048576, accuracy: 1e3)
    }
}
