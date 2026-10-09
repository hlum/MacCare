import Foundation
import AppKit
import Observation

struct DiskEntry: Decodable, Identifiable, Hashable {
    var name: String
    var path: String
    var size: Double
    var isDir: Bool
    var id: String { path }
}

struct AnalyzeResult: Decodable {
    var scanStatus: String?
    var path: String?
    var entries: [DiskEntry]?
}

@Observable
final class AnalyzeStore {
    var stack: [String] = [NSHomeDirectory()]
    var entries: [DiskEntry] = []
    var selected: DiskEntry?
    var loading = false
    var partial = false
    var notice: String?
    private var cache: [String: [DiskEntry]] = [:]
    private var token = 0

    var current: String { stack.last ?? NSHomeDirectory() }
    var total: Double { entries.reduce(0) { $0 + $1.size } }

    func load(force: Bool = false) {
        let path = current
        selected = nil; notice = nil
        if !force, let c = cache[path] { entries = c; partial = false; return }
        loading = true; entries = []
        token += 1; let mine = token
        Task { @MainActor in
            let r = await Mo.run(["analyze", "--json", path])
            guard mine == token else { return }
            loading = false
            guard let res = try? Mo.decoder.decode(AnalyzeResult.self, from: Data(r.out.utf8)) else {
                notice = "Couldn't read that folder."; return
            }
            let list = (res.entries ?? []).filter { $0.size > 0 }.sorted { $0.size > $1.size }
            entries = list; partial = res.scanStatus == "partial"
            if !partial { cache[path] = list }
            if list.isEmpty { notice = "Nothing here." }
        }
    }

    func enter(_ e: DiskEntry) { guard e.isDir else { return }; stack.append(e.path); load() }
    func jump(to index: Int) { stack = Array(stack.prefix(index + 1)); load() }
    func choose(_ path: String) { stack = [path]; load() }

    func trash(_ e: DiskEntry) {
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: e.path), resultingItemURL: nil)   // recoverable
            entries.removeAll { $0.path == e.path }; cache[current] = entries; selected = nil
        } catch { notice = "Couldn't move to Trash: \(error.localizedDescription)" }
    }

    func reveal(_ e: DiskEntry) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: e.path)]) }
}
