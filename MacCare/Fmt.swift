import Foundation

enum Fmt {
    /// 12_345_678 -> "11.8 MB". Decimal-free under 10 KB.
    static func bytes(_ n: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(n, 0), i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        if i == 0 { return "\(Int(v)) B" }
        return String(format: v >= 100 || i == 1 ? "%.0f %@" : "%.1f %@", v, units[i])
    }

    /// Split into number + unit for big display ("1.95", "GB").
    static func bigBytes(_ n: Double) -> (String, String) {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var v = max(n, 0), i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        return (String(format: i >= 3 ? "%.2f" : (v >= 100 ? "%.0f" : "%.1f"), v), units[i])
    }

    /// "12.3MB", "1.39GB", "16KB", "0B" -> bytes
    static func parseSize(_ s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces).uppercased()
        guard let r = t.range(of: "[KMGT]?B$", options: .regularExpression) else { return Double(t) ?? 0 }
        let num = Double(t[t.startIndex..<r.lowerBound].trimmingCharacters(in: .whitespaces)) ?? 0
        switch t[r].first {
        case "K": return num * 1024
        case "M": return num * 1024 * 1024
        case "G": return num * 1024 * 1024 * 1024
        case "T": return num * 1024 * 1024 * 1024 * 1024
        default: return num
        }
    }
}
