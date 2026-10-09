import SwiftUI
import AppKit

/// The app's real icon, or a letter tile when the bundle isn't on disk.
struct AppIcon: View {
    let path: String, name: String, size: CGFloat
    var body: some View {
        if FileManager.default.fileExists(atPath: path) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(Color.white.opacity(0.08))
                .overlay(Text(String(name.prefix(1))).font(.system(size: size * 0.42, weight: .medium)).foregroundStyle(T.soft))
                .frame(width: size, height: size)
        }
    }
}
