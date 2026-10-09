import SwiftUI

struct OptimizeView: View {
    @Environment(OptimizeStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 380)
            Scroller { timeline }.scrollIndicators(.hidden)
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(maxWidth: 1320).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { if store.phase == .idle { store.scan() } }
    }

    var left: some View {
        let total = store.steps.count
        let done = store.phase == .done ? total : min(store.current, total)
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: store.phase == .running ? "Optimize · running" : store.phase == .done ? "Optimize · done" : "Optimize")
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(store.phase == .scanning ? "—" : "\(store.phase == .ready || store.phase == .idle ? total : done)")
                    .font(.system(size: 120, weight: .medium)).tracking(-7).monospacedDigit().foregroundStyle(T.bone).contentTransition(.numericText())
                Text(store.phase == .running || store.phase == .done ? "/\(total)" : " steps").font(.system(size: 40, weight: .medium)).foregroundStyle(T.faint)
            }.padding(.top, 26)
            Text(store.phase == .done ? "finished. Some steps need an administrator password and are skipped without one."
                 : "Refreshing the caches and services macOS normally tidies on its own schedule. Nothing personal is touched.")
                .font(T.sans(17)).lineSpacing(4).foregroundStyle(T.mute).frame(maxWidth: 330, alignment: .leading).padding(.top, 20)

            ProgressLine(value: total > 0 ? Double(done) / Double(total) : 0).frame(height: 2).padding(.top, 40)

            HStack(spacing: 16) {
                switch store.phase {
                case .ready: Button { store.run() } label: { Text("Run \(total) steps") }.buttonStyle(PillButtonStyle())
                case .done: Button { store.phase = .idle; store.scan() } label: { Text("Run again") }.buttonStyle(PillButtonStyle(filled: false, icon: "arrow.clockwise"))
                default: HStack(spacing: 12) { Spinner(); Text(store.phase == .scanning ? "CHECKING" : "RUNNING").font(T.mono(11)).tracking(2).foregroundStyle(T.dim) }
                }
            }.padding(.top, 36)
            if let n = store.note { Text(n).font(T.mono(12)).foregroundStyle(T.caution).padding(.top, 22).frame(maxWidth: 330, alignment: .leading) }
            if let f = store.failed { Text(f).font(T.mono(12)).foregroundStyle(T.risky).padding(.top, 10).frame(maxWidth: 330, alignment: .leading) }
            Spacer()
        }
        .animation(T.spring, value: store.phase)
    }

    var timeline: some View {
        Bezel(radius: 30, padding: 28) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.steps.enumerated()), id: \.offset) { i, s in
                    let running = store.phase == .running && i == store.current
                    let finished = store.phase == .done || (store.phase == .running && i < store.current)
                    HStack(alignment: .top, spacing: 18) {
                        marker(running: running, finished: finished)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.name).font(T.sans(16, .medium)).foregroundStyle(finished || running ? T.bone : T.soft)
                            ForEach(s.results, id: \.self) { Text($0).font(T.sans(14)).foregroundStyle(T.dim) }
                        }
                        Spacer()
                        Text(running ? "RUNNING" : finished ? "DONE" : (store.phase == .ready ? "READY" : "QUEUED")).font(T.mono(11)).tracking(1.4)
                            .foregroundStyle(running ? T.accentSoft : finished ? T.safe : T.faint)
                    }.padding(.vertical, 14)
                    if i < store.steps.count - 1 { Divider().overlay(T.hair).padding(.leading, 46) }
                }
                if store.steps.isEmpty { Text(store.phase == .scanning ? "Checking what needs doing…" : "Nothing to do.").font(T.sans(15)).foregroundStyle(T.mute) }
            }
        }
    }

    func marker(running: Bool, finished: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(finished || running ? Color.clear : T.bone.opacity(0.2), lineWidth: 1)
            if finished { Circle().fill(T.bone); Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(T.bg) }
            else if running { Circle().fill(T.accent); Circle().fill(Color(hex: 0x140A04)).frame(width: 8, height: 8) }
        }.frame(width: 28, height: 28)
    }
}

struct ProgressLine: View {
    var value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(T.bone.opacity(0.1))
                Capsule().fill(T.accent).frame(width: g.size.width * min(max(value, 0), 1))
            }
        }.animation(T.spring, value: value)
    }
}
