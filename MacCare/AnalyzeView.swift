import SwiftUI

struct AnalyzeView: View {
    @Environment(AnalyzeStore.self) private var store

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 360)
            treemap
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(maxWidth: 1320).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { if store.entries.isEmpty && !store.loading { store.load() } }
    }

    var left: some View {
        let focus = store.selected
        let size = focus?.size ?? store.total
        let (n, u) = Fmt.bigBytes(size)
        return VStack(alignment: .leading, spacing: 0) {
            if store.stack.count > 1 {
                Button { withAnimation(T.spring) { store.jump(to: store.stack.count - 2) } } label: {
                    Label("Back to \(URL(fileURLWithPath: store.stack[store.stack.count - 2]).lastPathComponent)", systemImage: "chevron.left")
                }
                .buttonStyle(QuietButtonStyle()).keyboardShortcut("[", modifiers: .command)
                .padding(.bottom, 18)
            }
            breadcrumb
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(n).font(.system(size: 112, weight: .medium)).tracking(-6).monospacedDigit().foregroundStyle(T.bone)
                    .minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
                Text(u).font(.system(size: 28, weight: .medium)).foregroundStyle(T.mute)
            }.padding(.top, 26)
            Group {
                if let f = focus {
                    Text(f.name).foregroundStyle(T.bone) + Text(f.isDir ? " — folder. Double-click to look inside." : " — a single file.").foregroundStyle(T.mute)
                } else if store.loading {
                    Text("Scanning \(store.current.replacingOccurrences(of: NSHomeDirectory(), with: "~")). Big folders can take a minute.").foregroundStyle(T.mute)
                } else {
                    Text(store.notice ?? "Everything in this folder\(store.partial ? " (scan incomplete)" : ""). Click a block to select it.").foregroundStyle(T.mute)
                }
            }.font(T.sans(16)).lineSpacing(3).padding(.top, 18).frame(maxWidth: 320, alignment: .leading)

            HStack(spacing: 14) {
                Button { if let f = focus { store.trash(f) } } label: { Text("Move to Trash") }
                    .buttonStyle(PillButtonStyle(filled: false, icon: "trash")).disabled(focus == nil).opacity(focus == nil ? 0.4 : 1)
                Button("Reveal") { if let f = focus { store.reveal(f) } }.buttonStyle(QuietButtonStyle()).disabled(focus == nil)
            }.padding(.top, 36)

            HStack(spacing: 10) {
                Button("Choose folder") {
                    let p = NSOpenPanel(); p.canChooseDirectories = true; p.canChooseFiles = false
                    if p.runModal() == .OK, let u = p.url { store.choose(u.path) }
                }.buttonStyle(QuietButtonStyle())
                Button("Rescan") { store.load(force: true) }.buttonStyle(QuietButtonStyle())
            }.padding(.top, 14)

            Spacer(minLength: 30)
            Text("DOUBLE-CLICK TO GO INSIDE\nNOTHING IS DELETED, ONLY TRASHED").font(T.mono(11)).tracking(0.6).lineSpacing(5).foregroundStyle(T.faint)
        }
        .animation(T.spring, value: focus)
    }

    var breadcrumb: some View {
        let parts = store.stack.enumerated().map { ($0.offset, URL(fileURLWithPath: $0.element).lastPathComponent) }
        return HStack(spacing: 8) {
            ForEach(parts, id: \.0) { i, name in
                if i > 0 { Text("/").foregroundStyle(T.faint) }
                Button(name.isEmpty ? "Macintosh HD" : name) { store.jump(to: i) }.buttonStyle(.plain)
                    .foregroundStyle(i == parts.count - 1 ? T.bone : T.dim)
            }
        }.font(T.mono(11)).tracking(1.4).textCase(.uppercase).lineLimit(1)
    }

    var treemap: some View {
        Bezel(radius: 30, padding: 8) {
            GeometryReader { g in
                let shown = Array(store.entries.prefix(28))
                let rest = store.entries.dropFirst(28).reduce(0) { $0 + $1.size }
                let sizes = shown.map(\.size) + (rest > 0 ? [rest] : [])
                let rects = Treemap.layout(sizes, in: CGRect(origin: .zero, size: g.size))
                ZStack(alignment: .topLeading) {
                    ForEach(Array(rects.enumerated()), id: \.offset) { i, r in
                        if i < shown.count { tile(shown[i], r, rank: i) } else { otherTile(r) }
                    }
                    if store.loading {
                        VStack(spacing: 14) { ProgressView().controlSize(.large).tint(T.accent); Text("SCANNING").font(T.mono(11)).tracking(2.4).foregroundStyle(T.dim) }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(minHeight: 560)
        }
    }

    func tile(_ e: DiskEntry, _ r: CGRect, rank: Int) -> some View {
        let sel = store.selected == e
        let shade = 0.045 + 0.035 * Double((rank * 7) % 5) / 4
        return Button { withAnimation(T.spring) { store.selected = e } } label: {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(sel ? AnyShapeStyle(LinearGradient(colors: [T.accent.opacity(0.34), T.accent.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(shade)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(sel ? T.accent : Color.clear, lineWidth: 1.5))
                if r.width > 90 && r.height > 46 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(T.sans(r.width > 220 ? 16 : 13, .medium)).foregroundStyle(T.bone).lineLimit(1)
                        Text(Fmt.bytes(e.size)).font(T.mono(11)).foregroundStyle(T.mute)
                    }.padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: max(r.width - 5, 1), height: max(r.height - 5, 1))
        .offset(x: r.minX + 2.5, y: r.minY + 2.5)
        .simultaneousGesture(TapGesture(count: 2).onEnded { store.enter(e) })
        .contextMenu {
            Button("Reveal in Finder") { store.reveal(e) }
            Button("Move to Trash") { store.trash(e) }
        }
        .accessibilityLabel("\(e.name), \(Fmt.bytes(e.size))")
    }

    func otherTile(_ r: CGRect) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.025))
            .overlay(Text("MORE").font(T.mono(10)).foregroundStyle(T.faint))
            .frame(width: max(r.width - 5, 1), height: max(r.height - 5, 1)).offset(x: r.minX + 2.5, y: r.minY + 2.5)
    }
}
