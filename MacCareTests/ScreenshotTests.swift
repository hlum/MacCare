import XCTest
import SwiftUI
@testable import MacCare

/// Renders each screen offscreen with neutral sample data and writes PNGs to docs/images.
/// Run on demand:  MACCARE_SHOTS=1 xcodebuild test -only-testing:MacCareTests/ScreenshotTests ...
@MainActor
final class ScreenshotTests: XCTestCase {
    let outDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("docs/images")

    func render<V: View>(_ name: String, width: CGFloat, height: CGFloat, @ViewBuilder _ content: () -> V) throws {
        guard ProcessInfo.processInfo.environment["MACCARE_SHOTS"] == "1" else { throw XCTSkip("set MACCARE_SHOTS=1") }
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let r = ImageRenderer(content: content().frame(width: width, height: height).background(T.bg).preferredColorScheme(.dark).environment(\.snapshot, true))
        r.scale = 2
        let png = try XCTUnwrap(r.nsImage.flatMap { NSBitmapImageRep(data: $0.tiffRepresentation!)?.representation(using: .png, properties: [:]) })
        try png.write(to: outDir.appendingPathComponent("\(name).png"))
    }

    let status: StatusStore = {
        let s = StatusStore()
        let json = """
        {"uptime":"3d 4h","procs":512,"hardware":{"model":"MacBook Air","cpu_model":"Apple M2","total_ram":"16.0 GB","os_version":"macOS 26.0"},
         "health_score":93,"health_score_msg":"Excellent",
         "cpu":{"usage":14.2,"per_core":[31,27,19,18,9,4,2,2],"load1":1.62,"p_core_count":4,"e_core_count":4},
         "memory":{"used":13100000000,"total":17179869184,"used_percent":76.2,"swap_used":3100000000,"swap_total":5368709120},
         "disks":[{"mount":"/","used":151000000000,"total":245107195904,"used_percent":61.6,"external":false}],
         "network":[{"name":"en0","rx_rate_mbs":1.8,"tx_rate_mbs":0.12,"ip":"192.168.1.20"}],
         "batteries":[{"percent":87,"status":"discharging","time_left":"4:54","health":"Good","cycle_count":212}],
         "thermal":{"cpu_temp":0,"fan_speed":0},
         "top_processes":[{"pid":412,"name":"WindowServer","cpu":28.4,"memory_bytes":99975168},{"pid":2759,"name":"Browser Helper (Renderer)","cpu":16.8,"memory_bytes":350126080},
         {"pid":345,"name":"fseventsd","cpu":9.2,"memory_bytes":647168},{"pid":901,"name":"Xcode","cpu":7.1,"memory_bytes":1448128000},{"pid":1180,"name":"Terminal","cpu":3.4,"memory_bytes":210000000}]}
        """
        s.snap = try! Mo.decoder.decode(StatusSnapshot.self, from: Data(json.utf8))
        s.live = true
        var cpu: [Double] = [], rx: [Double] = []
        for i in 0..<60 {
            let x = Double(i)
            cpu.append(10.0 + 8.0 * sin(x / 5.0))
            let wobble: Double = Double(i % 7) * 0.05
            rx.append(max(0.05, 1.2 + 1.1 * sin(x / 4.0) + wobble))
        }
        s.cpuHist = cpu; s.rxHist = rx; s.txHist = [Double](repeating: 0.1, count: 60)
        return s
    }()

    func root(_ page: String, _ stores: (inout Env) -> Void = { _ in }) -> some View {
        UserDefaults.standard.set(page, forKey: "section")
        var env = Env(status: status); stores(&env)
        return RootView()
            .environment(env.status).environment(env.clean).environment(env.disk)
            .environment(env.xcode).environment(env.apps).environment(env.optimize)
    }

    struct Env { var status: StatusStore; var clean = CleanStore(); var disk = AnalyzeStore(); var xcode = XcodeStore(); var apps = AppsStore(); var optimize = OptimizeStore() }

    func testClean() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "clean-dry-run", withExtension: "txt"))
        let text = try String(contentsOf: url, encoding: .utf8)
        try render("clean", width: 1440, height: 940) {
            root("Clean") { e in
                var pv = CleanParser.parse(text)
                pv.groups = pv.groups.prefix(3).map { g in var g = g; g.items = Array(g.items.prefix(3)); return g }
                e.clean.preview = pv; e.clean.phase = .ready
                e.clean.off = ["Application Support"]
                e.clean.opened = e.clean.preview.groups.first?.items.first?.id
            }
        }
    }

    func testStatus() throws { try render("status", width: 1440, height: 1180) { root("Status") } }

    func testDisk() throws {
        let names: [(String, Double, Bool)] = [("Movies", 38e9, true), ("Projects", 21e9, true), ("Photos Library", 17e9, true), ("Downloads", 9.4e9, true),
            ("VM-images", 8.1e9, true), ("Music", 6.2e9, true), ("Documents", 3.3e9, true), ("Backup-2026.zip", 2.2e9, false), ("Desktop", 1.1e9, true), ("Public", 0.4e9, true)]
        try render("disk", width: 1440, height: 900) {
            root("Disk") { e in
                e.disk.stack = ["/Users/you", "/Users/you/Library"]
                e.disk.entries = names.map { DiskEntry(name: $0.0, path: "/Users/you/Library/\($0.0)", size: $0.1, isDir: $0.2) }
                e.disk.selected = e.disk.entries.first
            }
        }
    }

    func testXcode() throws {
        try render("xcode", width: 1440, height: 1220) {
            root("Xcode") { e in
                e.xcode.activeXcode = "/Applications/Xcode.app"
                e.xcode.sizes = ["derived": 9.4e9, "sims": 23.0e9, "runtimes": 11.1e9, "devicesupport": 6.6e9, "xcodecache": 0.4e9, "logs": 0.002e9, "spm": 0.9e9, "archives": 0.5e9]
                e.xcode.rows = ["sims": [PickRow(id: "a", title: "iPhone 17 Pro", subtitle: "iOS 26.0 · Shutdown", bytes: 7.5e9, target: .path("/x")),
                                         PickRow(id: "b", title: "iPad Pro 13-inch", subtitle: "iOS 26.0 · Shutdown", bytes: 4.1e9, target: .path("/y"))]]
            }
        }
    }

    func testApps() throws {
        let apps = [("Photo Studio", "com.example.photostudio", "1.2GB"), ("Notebook", "com.example.notebook", "640.3MB"), ("Sketchpad", "com.example.sketchpad", "103.5MB"), ("Menu Tools", "com.example.menutools", "12.3MB")]
        try render("apps", width: 1440, height: 780) {
            root("Apps") { e in
                e.apps.apps = apps.map { InstalledApp(name: $0.0, bundleId: $0.1, uninstallName: $0.0, path: "/Applications/\($0.0).app", size: $0.2) }
                e.apps.selected = e.apps.apps.first; e.apps.singleMatch = true
                e.apps.preview = [LeftoverFile(path: "/Applications/Photo Studio.app", bytes: 1.2e9), LeftoverFile(path: "~/Library/Application Support/Photo Studio", bytes: 84e6),
                                  LeftoverFile(path: "~/Library/Caches/com.example.photostudio", bytes: 31e6), LeftoverFile(path: "~/Library/Preferences/com.example.photostudio.plist", bytes: 4096)]
            }
        }
    }

    func testOptimize() throws {
        try render("optimize", width: 1440, height: 780) {
            root("Optimize") { e in
                e.optimize.steps = [OptStep(name: "DNS & Spotlight check", results: ["DNS cache flushed", "Spotlight index verified"]),
                                    OptStep(name: "Finder cache refresh", results: ["QuickLook thumbnails refreshed", "Icon services cache rebuilt"]),
                                    OptStep(name: "App state cleanup", results: ["App saved states optimized"]),
                                    OptStep(name: "Database optimization", results: ["Optimized 3 databases for Mail, Safari, Messages"]),
                                    OptStep(name: "Network cache refresh", results: ["mDNSResponder restarted"])]
                e.optimize.phase = .running; e.optimize.current = 2
            }
        }
    }

    func testMenuBar() throws {
        try render("menubar", width: 330, height: 412) { MenuBarPopover().environment(status) }
    }
}
