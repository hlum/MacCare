import SwiftUI

struct XcodeView: View {
    @Environment(XcodeStore.self) private var store
    @State private var opened: String? = "derived"
    @State private var picked: [String: Set<String>] = [:]
    enum Pending: Identifiable { case item(XcodeItem), rows(XcodeItem, [PickRow]), allSafe
        var id: String { switch self { case .item(let i): i.id; case .rows(let i, _): "r" + i.id; case .allSafe: "all" } } }
    @State private var pending: Pending?

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 380)
            Scroller { list }.scrollIndicators(.hidden)
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(maxWidth: 1320).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { if store.sizes.isEmpty { store.scan() } }
        .confirmationDialog(title, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible, presenting: pending) { p in
            Button(confirmLabel(p), role: .destructive) { run(p) }
            Button("Cancel", role: .cancel) {}
        } message: { p in Text(message(p)) }
    }

    // MARK: left

    var left: some View {
        let (n, u) = Fmt.bigBytes(store.total)
        let (sn, su) = Fmt.bigBytes(store.safeBytes)
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "Xcode · \(store.activeXcode ?? "…")")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.scanning && store.sizes.isEmpty ? "—" : n).font(.system(size: 120, weight: .medium)).tracking(-7).monospacedDigit()
                    .foregroundStyle(T.bone).minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
                Text(u).font(.system(size: 30, weight: .medium)).foregroundStyle(T.mute)
            }.padding(.top, 26)
            (Text("quietly piled up by Xcode. ").foregroundStyle(T.mute) + Text("\(sn) \(su)").foregroundStyle(T.bone) + Text(" of it rebuilds itself and can go right now.").foregroundStyle(T.mute))
                .font(T.sans(17)).lineSpacing(4).frame(maxWidth: 330, alignment: .leading).padding(.top, 20)

            footprint.padding(.top, 36)

            Button { pending = .allSafe } label: { Text("Clean everything safe · \(Fmt.bytes(store.safeBytes))") }
                .buttonStyle(PillButtonStyle()).disabled(store.safeBytes <= 0 || store.scanning).opacity(store.safeBytes <= 0 ? 0.4 : 1).padding(.top, 36)
            if store.xcodeRunning {
                Label("Quit Xcode and Simulator before cleaning so files aren't in use.", systemImage: "exclamationmark.triangle")
                    .font(T.sans(13)).foregroundStyle(T.caution).padding(.top, 18).frame(maxWidth: 330, alignment: .leading)
            }
            if let m = store.message { Text(m).font(T.sans(13)).foregroundStyle(T.risky).padding(.top, 12).frame(maxWidth: 330, alignment: .leading) }
            Spacer()
            HStack { if store.scanning { Spinner(); Text("MEASURING").font(T.mono(11)).tracking(2).foregroundStyle(T.dim) }
                Button("Rescan") { store.scan() }.buttonStyle(QuietButtonStyle()) }
        }
    }

    var footprint: some View {
        let parts = XcodeData.items.map { ($0, store.sizes[$0.id] ?? 0) }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(5)
        let shades: [Color] = [T.bone.opacity(0.55), T.bone.opacity(0.32), T.accent, T.accentSoft, T.risky]
        return VStack(alignment: .leading, spacing: 12) {
            GeometryReader { g in
                HStack(spacing: 3) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                        RoundedRectangle(cornerRadius: 3).fill(shades[i % shades.count]).frame(width: max(4, (g.size.width - 12) * p.1 / max(store.total, 1)))
                    }
                }
            }.frame(height: 14).animation(T.spring, value: store.total)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 8) { RoundedRectangle(cornerRadius: 2).fill(shades[i % shades.count]).frame(width: 8, height: 8)
                        Text("\(p.0.name) \(Fmt.bytes(p.1))").font(T.mono(12)).foregroundStyle(T.mute) }
                }
            }
        }
    }

    // MARK: list

    var list: some View {
        Bezel(radius: 30, padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(XcodeData.items.enumerated()), id: \.element.id) { i, it in
                    if i > 0 { Divider().overlay(T.hair) }
                    row(it)
                }
            }
        }
    }

    func row(_ it: XcodeItem) -> some View {
        let size = store.sizes[it.id] ?? 0
        let empty = size <= 0 && !store.scanning
        let open = opened == it.id
        return VStack(spacing: 0) {
            Button { withAnimation(T.spring) { opened = open ? nil : it.id } } label: {
                HStack(spacing: 14) {
                    Image(systemName: it.symbol).font(.system(size: 17, weight: .light)).frame(width: 22).foregroundStyle(open ? T.accent : (empty ? T.faint : T.mute))
                    Text(it.name).font(T.sans(15, .medium)).foregroundStyle(empty ? T.faint : T.bone)
                    if !empty { SafetyTag(safety: it.safety) }
                    Spacer()
                    Text(empty ? "empty" : Fmt.bytes(size)).font(T.mono(13)).foregroundStyle(empty ? T.faint : T.bone)
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).rotationEffect(.degrees(open ? 45 : 0))
                        .foregroundStyle(open ? T.bg : T.mute).frame(width: 26, height: 26)
                        .background(Circle().fill(open ? T.bone : Color.white.opacity(0.05)))
                }.padding(.horizontal, 24).padding(.vertical, 13).contentShape(Rectangle())
            }.buttonStyle(.plain)

            if open {
                VStack(alignment: .leading, spacing: 16) {
                    Text(it.paths.map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }.joined(separator: "\n"))
                        .font(T.mono(12)).foregroundStyle(T.mute).textSelection(.enabled)
                    HStack(alignment: .top, spacing: 0) {
                        col("What it is", it.what, T.dim)
                        col("+ You gain", it.gain, T.safe).overlay(alignment: .leading) { Rectangle().fill(T.hair).frame(width: 1) }
                        col("− You give up", it.lose, T.risky).overlay(alignment: .leading) { Rectangle().fill(T.hair).frame(width: 1) }
                    }
                    if it.picker { pickerList(it) }
                    HStack(spacing: 10) {
                        Spacer()
                        Button("Reveal in Finder") { store.reveal(it) }.buttonStyle(QuietButtonStyle())
                        actionButton(it, size: size, empty: empty)
                    }
                }
                .padding(.horizontal, 24).padding(.leading, 36).padding(.bottom, 20)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }

    @ViewBuilder func actionButton(_ it: XcodeItem, size: Double, empty: Bool) -> some View {
        if empty { Text("Nothing to clean").font(T.sans(13)).foregroundStyle(T.faint) }
        else if it.picker {
            let sel = (picked[it.id] ?? []).count
            let rows = (store.rows[it.id] ?? []).filter { (picked[it.id] ?? []).contains($0.id) }
            Button { pending = .rows(it, rows) } label: { Text(sel == 0 ? "Pick items to delete" : "Delete \(sel) · \(Fmt.bytes(rows.reduce(0) { $0 + $1.bytes }))") }
                .buttonStyle(PillButtonStyle(danger: it.safety == .risky, icon: nil)).disabled(sel == 0).opacity(sel == 0 ? 0.4 : 1)
        } else {
            Button { pending = .item(it) } label: { Text("Delete \(Fmt.bytes(size))") }
                .buttonStyle(PillButtonStyle(danger: it.safety == .risky, icon: nil)).disabled(store.busy != nil)
        }
    }

    func pickerList(_ it: XcodeItem) -> some View {
        let rows = store.rows[it.id] ?? []
        return VStack(spacing: 0) {
            ForEach(rows) { r in
                let on = (picked[it.id] ?? []).contains(r.id)
                Button { var s = picked[it.id] ?? []; if on { s.remove(r.id) } else { s.insert(r.id) }; picked[it.id] = s } label: {
                    HStack(spacing: 12) {
                        Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? T.accent : T.faint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(r.title).font(T.sans(14, .medium)).foregroundStyle(T.bone)
                            Text(r.subtitle).font(T.mono(11)).foregroundStyle(T.dim)
                        }
                        Spacer()
                        Text(Fmt.bytes(r.bytes)).font(T.mono(12)).foregroundStyle(T.mute)
                    }.padding(.vertical, 8).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider().overlay(T.hair)
            }
            if rows.isEmpty { Text(it.kind == .xcodeApps ? "No other Xcode installs found." : "Nothing listed.").font(T.sans(13)).foregroundStyle(T.faint).padding(.vertical, 8) }
        }
        .padding(.horizontal, 14).background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.03)))
    }

    func col(_ title: String, _ body: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(T.mono(10)).tracking(1.8).foregroundStyle(color)
            Text(body).font(T.sans(14)).lineSpacing(3).foregroundStyle(T.soft).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 16).frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: confirm + run

    var title: String {
        switch pending { case .item(let i): "Delete \(i.name)?"; case .rows(let i, let r): "Delete \(r.count) from \(i.name)?"; case .allSafe: "Clean everything marked safe?"; case nil: "" }
    }
    func confirmLabel(_ p: Pending) -> String {
        switch p { case .item: "Delete"; case .rows(let i, _): i.kind == .xcodeApps ? "Move to Trash" : "Delete"; case .allSafe: "Clean \(Fmt.bytes(store.safeBytes))" }
    }
    func message(_ p: Pending) -> String {
        switch p {
        case .item(let i): i.lose
        case .rows(let i, _): i.lose
        case .allSafe: "Only items tagged SAFE are cleaned. Simulators, runtimes, archives and other Xcode versions are never touched here."
        }
    }
    func run(_ p: Pending) {
        Task { @MainActor in
            switch p {
            case .item(let i): await store.clean(i); store.scan()
            case .rows(let i, let r): await store.delete(r, from: i); picked[i.id] = []
            case .allSafe: await store.cleanAllSafe()
            }
        }
    }
}
