import Foundation
import AppKit
import Observation

struct InstalledApp: Decodable, Identifiable, Hashable {
    var name: String
    var bundleId: String?
    var uninstallName: String
    var path: String
    var size: String
    var id: String { path }
    var bytes: Double { Fmt.parseSize(size) }
}

struct LeftoverFile: Identifiable, Hashable {
    var id: String { path }
    var path: String
    var bytes: Double
}

struct FileRow: Identifiable, Hashable {
    var id: String { path }
    var path: String
    var title: String
    var subtitle: String
    var bytes: Double
}

@Observable
final class AppsStore {
    enum Tab: String, CaseIterable { case uninstall = "Uninstall", login = "Login items", installers = "Installers" }
    var tab: Tab = .uninstall
    var apps: [InstalledApp] = []
    var query = ""
    var selected: InstalledApp?
    var preview: [LeftoverFile] = []
    var previewing = false
    var singleMatch = false          // dry run said "Matched 1 app(s)"
    var loading = false
    var running = false
    var log: [String] = []
    var message: String?
    var agents: [FileRow] = []
    var installers: [FileRow] = []
    var chosen: Set<String> = []

    var filtered: [InstalledApp] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return apps.filter { q.isEmpty || $0.name.lowercased().contains(q) || ($0.bundleId ?? "").lowercased().contains(q) }
    }
    var previewBytes: Double { preview.reduce(0) { $0 + $1.bytes } }

    func load() {
        guard apps.isEmpty, !loading else { return }
        loading = true
        Task { @MainActor in
            let r = await Mo.run(["uninstall", "--list"])
            apps = ((try? Mo.decoder.decode([InstalledApp].self, from: Data(r.out.utf8))) ?? []).sorted { $0.bytes > $1.bytes }
            loading = false
            if selected == nil, let f = apps.first { select(f) }
        }
        loadAgents(); loadInstallers()
    }

    func select(_ app: InstalledApp) {
        selected = app; preview = []; previewing = true; singleMatch = false; message = nil
        Task { @MainActor in
            // The dry run asks "Proceed? [y/N]" before it lists files, so answer yes. It changes nothing.
            let r = await Mo.run(["uninstall", "--dry-run", app.uninstallName], stdin: "y\n")
            guard selected == app else { return }
            preview = Self.parseFiles(r.out)
            // mo matches by name; one "y" confirms every match, so only allow the real run when exactly this app matched.
            singleMatch = r.out.contains("Matched 1 app(s)")
            if !singleMatch { message = "mo matched more than one app for that name, so uninstalling from here is disabled." }
            previewing = false
        }
    }

    /// Lines look like `  ✓ ~/Library/Preferences/x.plist , 4KB`.
    static func parseFiles(_ text: String) -> [LeftoverFile] {
        text.split(separator: "\n").compactMap { raw in
            let t = raw.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("✓ ") else { return nil }
            let body = String(t.dropFirst(2))
            guard let r = body.range(of: " , ", options: .backwards) else { return nil }
            return LeftoverFile(path: String(body[..<r.lowerBound]), bytes: Fmt.parseSize(String(body[r.upperBound...])))
        }
    }

    func uninstall() {
        guard let app = selected, singleMatch, !running else { return }
        running = true; log = []; message = nil
        Activity.shared.begin()
        Task { @MainActor in
            // First prompt: y + Enter. Second: Enter to confirm.
            let run = Proc.lines(Mo.path, ["uninstall", app.uninstallName], stdin: "y\n\n")
            for await l in run.stream { let t = Proc.stripANSI(l).trimmingCharacters(in: .whitespaces); if !t.isEmpty { log.append(t) } }
            let code = await run.wait()
            Activity.shared.end()
            running = false
            // Trust the disk, not the exit code: root-owned apps need sudo, which can't be asked for here.
            if FileManager.default.fileExists(atPath: app.path) {
                select(app)
                message = "\(app.name) is still installed (mo exited with \(code)). It may need an administrator password; try `mo uninstall` in Terminal."
            } else {
                apps.removeAll { $0.id == app.id }
                selected = nil; preview = []
                if let f = apps.first { select(f) }
            }
        }
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
    }

    // MARK: login items / installers (read the folders directly)

    func loadAgents() {
        let dir = NSHomeDirectory() + "/Library/LaunchAgents"
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { $0.hasSuffix(".plist") }.sorted()
        agents = names.map { n in
            let p = dir + "/" + n
            let d = NSDictionary(contentsOfFile: p)
            let prog = (d?["Program"] as? String) ?? ((d?["ProgramArguments"] as? [String])?.first ?? "")
            return FileRow(path: p, title: (d?["Label"] as? String) ?? n, subtitle: prog, bytes: 0)
        }
    }

    func loadInstallers() {
        let exts: Set<String> = ["dmg", "pkg", "iso", "xip"]
        var rows: [FileRow] = []
        for dir in [NSHomeDirectory() + "/Downloads", NSHomeDirectory() + "/Desktop"] {
            for n in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where exts.contains((n as NSString).pathExtension.lowercased()) {
                let p = dir + "/" + n
                let size = ((try? FileManager.default.attributesOfItem(atPath: p))?[.size] as? NSNumber)?.doubleValue ?? 0
                rows.append(FileRow(path: p, title: n, subtitle: (dir as NSString).lastPathComponent, bytes: size))
            }
        }
        installers = rows.sorted { $0.bytes > $1.bytes }
    }

    /// Installers go to the Trash, so they can be put back.
    func trashChosen() {
        for r in installers where chosen.contains(r.id) { try? FileManager.default.trashItem(at: URL(fileURLWithPath: r.path), resultingItemURL: nil) }
        chosen = []; loadInstallers()
    }
}
