import Foundation
import AppKit
import Observation

struct PickRow: Identifiable, Hashable {
    enum Target: Hashable { case path(String), simulator(String, booted: Bool), runtime(String) }
    let id: String
    let title: String
    let subtitle: String
    let bytes: Double
    let target: Target
}

@Observable
final class XcodeStore {
    var sizes: [String: Double] = [:]
    var rows: [String: [PickRow]] = [:]          // picker rows by item id
    var scanning = false
    var busy: String?                            // item id being cleaned
    var message: String?
    var activeXcode: String?
    var hasSimctl = false

    var total: Double { sizes.values.reduce(0, +) }
    var safeBytes: Double { XcodeData.items.filter { $0.safety == .safe }.reduce(0) { $0 + (sizes[$1.id] ?? 0) } }
    var xcodeRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { ["com.apple.dt.Xcode", "com.apple.iphonesimulator"].contains($0.bundleIdentifier ?? "") }
    }

    private struct Dev { var uuid: String; var name: String; var runtime: String; var state: String; var ok: Bool }

    func scan() {
        guard !scanning else { return }
        scanning = true; message = nil
        Task { @MainActor in
            let sel = await Proc.run("/usr/bin/xcode-select", ["-p"])
            activeXcode = sel.out.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/Contents/Developer", with: "")
            hasSimctl = (await Proc.run("/usr/bin/xcrun", ["simctl", "help"])).ok

            let devices = hasSimctl ? await loadDevices() : []
            let runtimes = hasSimctl ? await loadRuntimes() : []
            var s: [String: Double] = [:]
            var r: [String: [PickRow]] = [:]

            for it in XcodeData.items where it.kind == .paths || it.kind == .testClones {
                s[it.id] = await du(it.paths)
            }
            // Simulators: size each device directory once.
            var sized: [(Dev, Double)] = []
            for d in devices { sized.append((d, await du(["\(XcodeData.dev)/CoreSimulator/Devices/\(d.uuid)"]))) }
            s["unavail"] = sized.filter { !$0.0.ok }.reduce(0) { $0 + $1.1 }
            s["sims"] = sized.filter { $0.0.ok }.reduce(0) { $0 + $1.1 }
            r["sims"] = sized.filter { $0.0.ok }.map {
                PickRow(id: $0.0.uuid, title: $0.0.name, subtitle: "\($0.0.runtime) · \($0.0.state)", bytes: $0.1, target: .simulator($0.0.uuid, booted: $0.0.state == "Booted"))
            }.sorted { $0.bytes > $1.bytes }
            s["runtimes"] = runtimes.reduce(0) { $0 + $1.bytes }
            r["runtimes"] = runtimes.sorted { $0.bytes > $1.bytes }

            for id in ["devicesupport"] {
                let kids = XcodeData.supportRoots.flatMap { children(of: $0) }
                var list: [PickRow] = []
                for k in kids { list.append(PickRow(id: k, title: (k as NSString).lastPathComponent, subtitle: ((k as NSString).deletingLastPathComponent as NSString).lastPathComponent, bytes: await du([k]), target: .path(k))) }
                r[id] = list.sorted { $0.bytes > $1.bytes }
                s[id] = await du(XcodeData.supportRoots)
            }
            let archives = findArchives()
            var arows: [PickRow] = []
            for a in archives { arows.append(PickRow(id: a, title: ((a as NSString).lastPathComponent as NSString).deletingPathExtension, subtitle: ((a as NSString).deletingLastPathComponent as NSString).lastPathComponent, bytes: await du([a]), target: .path(a))) }
            r["archives"] = arows.sorted { $0.bytes > $1.bytes }
            s["archives"] = await du([XcodeData.dev + "/Xcode/Archives"])

            let others = otherXcodes()
            var xrows: [PickRow] = []
            for a in others { xrows.append(PickRow(id: a, title: (a as NSString).lastPathComponent, subtitle: "/Applications", bytes: await du([a]), target: .path(a))) }
            r["xcodeapps"] = xrows
            s["xcodeapps"] = xrows.reduce(0) { $0 + $1.bytes }

            sizes = s; rows = r; scanning = false
        }
    }

    // MARK: actions

    /// Clean a non-picker item. Returns after finishing.
    func clean(_ it: XcodeItem) async {
        busy = it.id; Activity.shared.begin(); defer { busy = nil; Activity.shared.end() }
        switch it.kind {
        case .paths:
            for p in it.paths { _ = DeleteGuard.empty(p, activeXcode: activeXcode) }
        case .testClones:
            if hasSimctl { _ = await Proc.run("/usr/bin/xcrun", ["simctl", "--set", "testing", "delete", "all"]) }
            _ = DeleteGuard.empty(XcodeData.dev + "/XCTestDevices", activeXcode: activeXcode)
        case .unavailable:
            if hasSimctl { _ = await Proc.run("/usr/bin/xcrun", ["simctl", "delete", "unavailable"]) }
        case .deviceSupport:
            for p in XcodeData.supportRoots { _ = DeleteGuard.empty(p, activeXcode: activeXcode) }
        default: break
        }
    }

    func cleanAllSafe() async {
        for it in XcodeData.items where it.safety == .safe && (sizes[it.id] ?? 0) > 0 { await clean(it) }
        scanning = false; scan()
    }

    func delete(_ picked: [PickRow], from it: XcodeItem) async {
        busy = it.id; Activity.shared.begin(); defer { busy = nil; Activity.shared.end() }
        var failures = 0
        for row in picked {
            switch row.target {
            case .path(let p):
                let trash = it.kind == .xcodeApps       // whole Xcode apps go to the Trash so they can be put back
                if case .removed = DeleteGuard.remove(p, activeXcode: activeXcode, trash: trash) {} else { failures += 1 }
            case .simulator(let uuid, let booted):
                if booted { _ = await Proc.run("/usr/bin/xcrun", ["simctl", "shutdown", uuid]) }
                if !(await Proc.run("/usr/bin/xcrun", ["simctl", "delete", uuid])).ok { failures += 1 }
            case .runtime(let id):
                if !(await Proc.run("/usr/bin/xcrun", ["simctl", "runtime", "delete", id])).ok { failures += 1 }
            }
        }
        message = failures == 0 ? nil : "\(failures) item(s) couldn't be removed. They may be in use or protected by macOS."
        scanning = false; scan()
    }

    func reveal(_ it: XcodeItem) {
        let first = it.paths.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? XcodeData.dev
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: first)])
    }

    // MARK: helpers

    private func du(_ paths: [String]) async -> Double {
        let existing = paths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existing.isEmpty else { return 0 }
        let r = await Proc.run("/usr/bin/du", ["-skx"] + existing)
        return r.out.split(separator: "\n").reduce(0) { $0 + (Double($1.split(separator: "\t").first ?? "") ?? 0) * 1024 }
    }

    private func children(of dir: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { !$0.hasPrefix(".") }.map { dir + "/" + $0 }
    }

    private func findArchives() -> [String] {
        let root = XcodeData.dev + "/Xcode/Archives"
        return children(of: root).flatMap { children(of: $0) }.filter { $0.hasSuffix(".xcarchive") }
    }

    private func otherXcodes() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: "/Applications")) ?? [])
            .filter { $0.hasPrefix("Xcode") && $0.hasSuffix(".app") }.map { "/Applications/" + $0 }
            .filter { $0 != activeXcode }
    }

    private func loadDevices() async -> [Dev] {
        let r = await Proc.run("/usr/bin/xcrun", ["simctl", "list", "devices"])
        var out: [Dev] = [], runtime = ""
        let head = try! NSRegularExpression(pattern: #"^-- (.*) --$"#)
        let dev = try! NSRegularExpression(pattern: #"^ +(.*) \(([0-9A-F-]{36})\) \(([^)]*)\)"#)
        for line in r.out.split(separator: "\n").map(String.init) {
            let ns = line as NSString, whole = NSRange(location: 0, length: ns.length)
            if let m = head.firstMatch(in: line, range: whole) { runtime = ns.substring(with: m.range(at: 1)); continue }
            if let m = dev.firstMatch(in: line, range: whole) {
                out.append(Dev(uuid: ns.substring(with: m.range(at: 2)), name: ns.substring(with: m.range(at: 1)), runtime: runtime,
                               state: ns.substring(with: m.range(at: 3)), ok: !line.contains("unavailable")))
            }
        }
        return out
    }

    private func loadRuntimes() async -> [PickRow] {
        let r = await Proc.run("/usr/bin/xcrun", ["simctl", "runtime", "list", "-v"])
        var rows: [PickRow] = []
        let head = try! NSRegularExpression(pattern: #"^([A-Za-z].*) - ([0-9A-F-]{36})"#)
        var name = "", id = "", size = 0.0, used = "?", deletable = true
        func flush() { if !id.isEmpty && deletable { rows.append(PickRow(id: id, title: name, subtitle: "last used \(used)", bytes: size, target: .runtime(id))) } }
        for line in r.out.split(separator: "\n").map(String.init) {
            let ns = line as NSString
            if let m = head.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) {
                flush(); name = ns.substring(with: m.range(at: 1)); id = ns.substring(with: m.range(at: 2)); size = 0; used = "?"; deletable = true
            } else if let r = line.range(of: "Size: ") { size = Fmt.parseSize(String(line[r.upperBound...]).replacingOccurrences(of: " ", with: "")) }
            else if let r = line.range(of: "Last Used At: ") { used = String(line[r.upperBound...]).split(separator: " ").first.map(String.init) ?? "?" }
            else if let r = line.range(of: "Deletable: ") { deletable = String(line[r.upperBound...]).hasPrefix("YES") }
        }
        flush()
        return rows
    }
}
