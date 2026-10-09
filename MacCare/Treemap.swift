import CoreGraphics

/// Squarified treemap (Bruls, Huijsen, van Wijk). Input sizes must be sorted descending and positive.
/// Returns one rect per input, in order, tiling `rect` exactly.
enum Treemap {
    static func layout(_ sizes: [Double], in rect: CGRect) -> [CGRect] {
        let total = sizes.reduce(0, +)
        guard total > 0, !sizes.isEmpty else { return [] }
        let scale = Double(rect.width * rect.height) / total
        let areas = sizes.map { $0 * scale }
        var out = [CGRect](repeating: .zero, count: sizes.count)
        var free = rect
        var i = 0
        while i < areas.count {
            let side = Double(min(free.width, free.height))
            var row = [i]
            var worst = worstRatio(areas[i...i], side)
            var j = i + 1
            while j < areas.count {
                let candidate = worstRatio(areas[i...j], side)
                if candidate > worst { break }
                worst = candidate; row.append(j); j += 1
            }
            let rowArea = row.reduce(0.0) { $0 + areas[$1] }
            let horizontal = free.width >= free.height   // lay the row along the short side
            if horizontal {
                let w = CGFloat(rowArea / Double(free.height))
                var y = free.minY
                for k in row { let h = CGFloat(areas[k] / Double(w)); out[k] = CGRect(x: free.minX, y: y, width: w, height: h); y += h }
                free = CGRect(x: free.minX + w, y: free.minY, width: free.width - w, height: free.height)
            } else {
                let h = CGFloat(rowArea / Double(free.width))
                var x = free.minX
                for k in row { let w = CGFloat(areas[k] / Double(h)); out[k] = CGRect(x: x, y: free.minY, width: w, height: h); x += w }
                free = CGRect(x: free.minX, y: free.minY + h, width: free.width, height: free.height - h)
            }
            i += row.count
        }
        return out
    }

    private static func worstRatio(_ row: ArraySlice<Double>, _ side: Double) -> Double {
        let s = row.reduce(0, +)
        guard let mx = row.max(), let mn = row.min(), s > 0, mn > 0 else { return .infinity }
        return max(side * side * mx / (s * s), (s * s) / (side * side * mn))
    }
}
