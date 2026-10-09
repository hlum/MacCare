import Foundation
import Observation

/// Scan → pick → clean, on top of `mo clean`.
/// mo can't clean one item at a time, so unchecking a group protects that group's paths for one run
/// through a temporary block in mo's whitelist file, which is always restored afterwards.
@Observable
final class CleanStore {
    enum Phase { case idle, scanning, ready, running, done }

    var phase: Phase = .idle
    var preview = CleanPreview()
    var off: Set<String> = []                // unchecked group names
    var trashOn = false                      // emptying Trash is opt-in
    var opened: String?                      // item id with "Why?" expanded
    var log: [String] = []
    var message: String?
    var freedBytes: Double?          // change in free disk space (lags, and other activity moves it)
    var trackedBytes: Double?        // what mo itself reports it removed
    var previewedBytes: Double = 0   // what we promised before the run
    var historyDone = false

    private var groupPaths: [String: [String]] = [:]
    private var corePatterns: [String] = []
    private static let begin = "# maccare-temp-begin", end = "# maccare-temp-end"
    static var whitelistURL: URL { URL(fileURLWithPath: NSHomeDirectory() + "/.config/mole/whitelist") }
    static var listURL: URL { URL(fileURLWithPath: NSHomeDirectory() + "/.config/mole/clean-list.txt") }

    var selectedBytes: Double {
        preview.groups.filter { !off.contains($0.name) }.reduce(0) { sum, g in
            sum + g.items.filter { !$0.reviewOnly && ($0.name.lowercased() != "trash" || trashOn) }.reduce(0) { $0 + ($1.bytes ?? 0) }
        }
    }
    var allBytes: Double { preview.groups.reduce(0) { $0 + $1.bytes } }

    func scan() {
        guard phase != .scanning, phase != .running else { return }
        phase = .scanning; message = nil
        Task { @MainActor in
            let r = await Mo.run(["clean", "--dry-run"])
            guard r.ok || !r.out.isEmpty else { phase = .idle; message = "mo clean failed: \(r.err.prefix(200))"; return }
            preview = CleanParser.parse(r.out)
            corePatterns = r.out.split(separator: "\n")
                .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("↳ ") }
                .map { $0.trimmingCharacters(in: .whitespaces).dropFirst(2).trimmingCharacters(in: .whitespaces) }
                .filter { !$0.contains(Self.begin) }
            groupPaths = Self.readGroupPaths()
            phase = .ready
        }
    }

    // MARK: - clean

    func clean() {
        guard phase == .ready else { return }
        var protect: [String] = []
        for g in preview.groups where off.contains(g.name) { protect += groupPaths[g.name] ?? [] }
        if !trashOn { protect += [NSHomeDirectory() + "/.Trash", NSHomeDirectory() + "/.Trash/*"] }
        // Replacing the whitelist drops mo's convenience defaults (ollama models, gradle...). Refuse rather than risk it.
        if !protect.isEmpty && corePatterns.isEmpty { message = "Couldn't read mo's protected paths, so nothing was cleaned."; return }

        phase = .running; log = []; message = nil; trackedBytes = nil; previewedBytes = selectedBytes
        let before = Self.freeBytes()
        Activity.shared.begin()
        Task { @MainActor in
            let restore = protect.isEmpty ? {} : Self.installTemp(protect, core: corePatterns)
            let run = Proc.lines(Mo.path, ["clean"])
            for await line in run.stream {
                let t = Proc.stripANSI(line).trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { log.append(t) }
            }
            let code = await run.wait()
            restore()
            Activity.shared.end()
            freedBytes = max(0, Self.freeBytes() - before)
            trackedBytes = log.compactMap { Self.tracked(in: $0) }.last
            if code != 0 { message = "mo clean exited with code \(code). Check the output for what went wrong." }
            else if log.contains(where: { $0.localizedCaseInsensitiveContains("canceled") }) { message = "mo cancelled the run, so nothing was cleaned." }
            phase = .done
        }
    }

    func reset() { phase = .idle; scan() }

    // MARK: - whitelist plumbing

    /// Adds a marked block to the whitelist. Returns a closure that puts the file back exactly as it was.
    static func installTemp(_ patterns: [String], core: [String], at url: URL = whitelistURL) -> () -> Void {
        let fm = FileManager.default
        let original = try? Data(contentsOf: url)
        var text = original.map { String(decoding: $0, as: UTF8.self) } ?? core.joined(separator: "\n")
        if !text.hasSuffix("\n") { text += "\n" }
        text += begin + "\n" + patterns.joined(separator: "\n") + "\n" + end + "\n"
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
        return {
            if let original { try? original.write(to: url, options: .atomic) } else { try? fm.removeItem(at: url) }
        }
    }

    /// If the app died mid-clean, strip our block (and delete the file if it only held our block + defaults).
    static func recoverLeftoverWhitelist(at url: URL = whitelistURL) {
        guard let s = try? String(contentsOf: url, encoding: .utf8), s.contains(begin) else { return }
        var kept: [String] = [], skipping = false
        for line in s.split(separator: "\n", omittingEmptySubsequences: false) {
            if line == Substring(begin) { skipping = true; continue }
            if line == Substring(end) { skipping = false; continue }
            if !skipping { kept.append(String(line)) }
        }
        try? kept.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    static func readGroupPaths() -> [String: [String]] {
        guard let s = try? String(contentsOf: listURL, encoding: .utf8) else { return [:] }
        var out: [String: [String]] = [:], cur: String?
        for line in s.split(separator: "\n") {
            if line.hasPrefix("=== "), line.hasSuffix(" ===") { cur = String(line.dropFirst(4).dropLast(4)); continue }
            guard let c = cur, line.hasPrefix("/") else { continue }
            let path = line.components(separatedBy: "  # ").first ?? String(line)
            out[c, default: []].append(path)
        }
        return out
    }

    /// "Tracked cleanup: 1.86GB" or "Tracked cleanup: At least 1.2GB"
    static func tracked(in line: String) -> Double? {
        guard line.contains("Tracked cleanup:"),
              let r = line.range(of: #"[0-9]+(\.[0-9]+)?\s?(KB|MB|GB|TB|B)\b"#, options: .regularExpression) else { return nil }
        return Fmt.parseSize(String(line[r]))
    }

    static func freeBytes() -> Double {
        let v = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Double(v?.volumeAvailableCapacityForImportantUsage ?? 0)
    }
}
