import Foundation

struct CleanItem: Identifiable, Hashable {
    var id: String { group + "/" + name }
    var group: String
    var name: String
    var count: Int?
    var bytes: Double?          // nil when mo doesn't report a size ("would clean")
    var note: String            // raw detail text, e.g. "would empty, 11 items"
    var reviewOnly: Bool        // "⊙" lines: mo only points at them
}

struct CleanGroup: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var items: [CleanItem]
    var bytes: Double { items.filter { !$0.reviewOnly }.reduce(0) { $0 + ($1.bytes ?? 0) } }
    var cleanable: Bool { items.contains { !$0.reviewOnly } }
}

struct CleanPreview {
    var groups: [CleanGroup] = []
    var potentialBytes: Double?
    var needsSudoNote = false
    var freeSpace: String?
}

/// Parses the text of `mo clean --dry-run` (ANSI already stripped).
/// Lines look like:  `➤ Section`, `  → Name · 10 items, 1.83GB dry`, `  → Name · would clean`,
/// `  → Name, would clean 51.0MB, 0 protected`, `  → Trash · would empty, 11 items`, `  ⊙ review-only`, `  ✓ Nothing to clean`.
enum CleanParser {
    static func parse(_ text: String) -> CleanPreview {
        var out = CleanPreview()
        var current: CleanGroup?
        func flush() { if let g = current, g.cleanable { out.groups.append(g) }; current = nil }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("➤ ") { flush(); current = CleanGroup(name: String(t.dropFirst(2)), items: []); continue }
            if t.hasPrefix("Potential space:") {
                if let m = t.range(of: #"Potential space:\s*([0-9.]+\s?[KMGT]?B)"#, options: .regularExpression) {
                    let s = String(t[m]).replacingOccurrences(of: "Potential space:", with: "")
                    out.potentialBytes = Fmt.parseSize(s)
                }
                continue
            }
            if t.contains("System caches need sudo") { out.needsSudoNote = true; continue }
            if t.hasPrefix("⚙"), let r = t.range(of: "Free space:") { out.freeSpace = String(t[r.upperBound...]).trimmingCharacters(in: .whitespaces); continue }
            guard current != nil else { continue }

            let review = t.hasPrefix("⊙ ")
            guard t.hasPrefix("→ ") || review else { continue }       // skips "✓ Nothing to clean" and indented sub-lines
            let body = String(t.dropFirst(2))
            current!.items.append(item(body, group: current!.name, review: review))
        }
        flush()
        return out
    }

    private static func item(_ body: String, group: String, review: Bool) -> CleanItem {
        // Name ends at " · " or, for the "Name, would clean …" shape, at ", would".
        var name = body, detail = ""
        if let r = body.range(of: " · ") { name = String(body[..<r.lowerBound]); detail = String(body[r.upperBound...]) }
        else if let r = body.range(of: ", would") { name = String(body[..<r.lowerBound]); detail = String(body[r.lowerBound...].dropFirst(2)) }
        let count = firstInt(in: detail, before: "item")
        let bytes = review ? nil : firstSize(in: detail)
        return CleanItem(group: group, name: name, count: count, bytes: bytes, note: detail, reviewOnly: review)
    }

    private static func firstSize(in s: String) -> Double? {
        guard let r = s.range(of: #"[0-9]+(\.[0-9]+)?\s?(KB|MB|GB|TB|B)\b"#, options: .regularExpression) else { return nil }
        return Fmt.parseSize(String(s[r]))
    }

    private static func firstInt(in s: String, before word: String) -> Int? {
        guard let r = s.range(of: #"([0-9]+) "# + word, options: .regularExpression) else { return nil }
        return Int(s[r].split(separator: " ").first ?? "")
    }
}
