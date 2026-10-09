import SwiftUI

struct MenuBarLabel: View {
    @Environment(StatusStore.self) private var store
    var body: some View {
        Text("\(Int((store.snap.cpu?.usage ?? 0).rounded()))% · \(Int((store.snap.memory?.usedPercent ?? 0).rounded()))%")
            .font(T.mono(12))
    }
}

struct MenuBarPopover: View {
    @Environment(StatusStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let s = store.snap
        let d = store.startDisk
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                stat("CPU", "\(Int((s.cpu?.usage ?? 0).rounded()))", "%", T.bone)
                stat("MEMORY", "\(Int((s.memory?.usedPercent ?? 0).rounded()))", "%", (s.memory?.usedPercent ?? 0) > 75 ? T.caution : T.bone)
                let free = (d?.total ?? 0) - (d?.used ?? 0)
                let (n, u) = Fmt.bigBytes(free)
                stat("FREE", free >= 1_000_000_000 ? String(format: "%.0f", Double(n) ?? 0) : n, u, T.bone)
            }
            Sparkline(values: store.cpuHist, color: T.accent, fill: false).frame(height: 40)
            HStack {
                Text("↓ \(String(format: "%.1f", store.rx)) MB/s"); Spacer(); Text("↑ \(String(format: "%.0f", store.tx * 1024)) KB/s")
            }.font(T.mono(11)).foregroundStyle(T.mute)
            Divider().overlay(T.hair)
            ToolsList()
            LoginToggle()
            Divider().overlay(T.hair)
            HStack {
                Button("Open MacCare") { NSApp.activate(ignoringOtherApps: true); openWindow(id: "main") }
                    .buttonStyle(.plain).foregroundStyle(T.soft)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(T.dim)
            }.font(T.sans(13))
        }
        .padding(18).frame(width: 330)
        .background(T.panel)
        .preferredColorScheme(.dark)
    }

    func stat(_ l: String, _ v: String, _ u: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: l)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(v).font(.system(size: 30, weight: .medium)).tracking(-1.5).monospacedDigit().foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.6)
                Text(u).font(T.sans(14)).foregroundStyle(T.mute).lineLimit(1)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
