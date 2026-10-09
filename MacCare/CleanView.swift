import SwiftUI

struct CleanView: View {
    @Environment(CleanStore.self) private var store
    @State private var confirming = false
    var openXcode: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 380)
            right
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(maxWidth: 1320).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { if store.phase == .idle { store.scan() } }
        .confirmationDialog("Clean \(Fmt.bytes(store.selectedBytes))?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Clean \(Fmt.bytes(store.selectedBytes))", role: .destructive) { store.clean() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the checked groups are cleaned. \(store.trashOn ? "The Trash will be emptied and can't be recovered." : "Trash is left alone.")")
        }
    }

    // MARK: left

    var left: some View {
        let big = store.phase == .done ? (store.trackedBytes ?? store.freedBytes ?? 0) : store.selectedBytes
        let (n, u) = Fmt.bigBytes(big)
        return VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: eyebrow)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.phase == .scanning ? "—" : n).font(.system(size: 120, weight: .medium)).tracking(-7).monospacedDigit()
                    .foregroundStyle(T.bone).minimumScaleFactor(0.5).lineLimit(1).contentTransition(.numericText())
                Text(store.phase == .scanning ? "" : u).font(.system(size: 30, weight: .medium)).foregroundStyle(T.mute)
            }.padding(.top, 26)
            Text(blurb).font(T.sans(17)).lineSpacing(4).foregroundStyle(T.mute).frame(maxWidth: 330, alignment: .leading).padding(.top, 20)

            TickBar(value: store.allBytes > 0 ? store.selectedBytes / store.allBytes : 0).frame(height: 44).padding(.top, 36)
            HStack(spacing: 18) {
                legend(T.accent, "Selected"); legend(T.bone.opacity(0.14), "Protected this run")
            }.padding(.top, 12)

            actions.padding(.top, 40)
            if let m = store.message { Text(m).font(T.sans(13)).foregroundStyle(T.risky).padding(.top, 14) }
            Spacer(minLength: 24)
            xcodeCard
        }
        .animation(T.spring, value: store.phase)
    }

    var eyebrow: String {
        switch store.phase {
        case .idle: "Clean"
        case .scanning: "Clean · scanning"
        case .ready: "Clean · ready to review"
        case .running: "Clean · running"
        case .done: "Clean · done"
        }
    }

    var blurb: String {
        switch store.phase {
        case .idle, .scanning: "Looking through caches, logs and leftovers. Nothing is changed during a scan."
        case .ready: "selected from your user folders. Nothing is removed until you confirm, and every item tells you what you give up."
        case .running: "Working. Keep this window open until it finishes."
        case .done:
            "removed, as reported by mo. Preview said \(Fmt.bytes(store.previewedBytes)); the gap is files that were in use, rebuilt while it ran, or already protected. Disk free changed by \(Fmt.bytes(store.freedBytes ?? 0)); macOS can take a minute to report it."
        }
    }

    @ViewBuilder var actions: some View {
        switch store.phase {
        case .ready:
            HStack(spacing: 16) {
                Button { confirming = true } label: { Text("Clean \(Fmt.bytes(store.selectedBytes))") }
                    .buttonStyle(PillButtonStyle()).disabled(store.selectedBytes <= 0 && !store.trashOn)
                Button("Rescan") { store.reset() }.buttonStyle(QuietButtonStyle())
            }
            if store.preview.needsSudoNote {
                Label("System caches need an administrator password and are skipped.", systemImage: "lock")
                    .font(T.sans(12)).foregroundStyle(T.dim).padding(.top, 18).frame(maxWidth: 320, alignment: .leading)
            }
        case .done:
            Button { store.reset() } label: { Text("Scan again") }.buttonStyle(PillButtonStyle(filled: false, icon: "arrow.clockwise"))
        case .scanning, .running:
            HStack(spacing: 12) { Spinner(); Text(store.phase == .scanning ? "SCANNING" : "CLEANING").font(T.mono(11)).tracking(2).foregroundStyle(T.dim) }
        case .idle:
            Button("Scan") { store.scan() }.buttonStyle(QuietButtonStyle())
        }
    }

    func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) { RoundedRectangle(cornerRadius: 2).fill(c).frame(width: 8, height: 8); Text(t).font(T.mono(11)).foregroundStyle(T.dim) }
    }

    var xcodeCard: some View {
        Button(action: openXcode) {
            Bezel(radius: 26, padding: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "hammer").font(.system(size: 20, weight: .light)).foregroundStyle(T.mute)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Xcode keeps its own pile").font(T.sans(15, .medium)).foregroundStyle(T.bone)
                        Text("Simulators, DerivedData and more have their own page.").font(T.sans(13)).foregroundStyle(T.dim)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(T.bone)
                        .frame(width: 32, height: 32).background(Circle().fill(Color.white.opacity(0.06)))
                }
            }
        }.buttonStyle(.plain)
    }

    // MARK: right

    @ViewBuilder var right: some View {
        switch store.phase {
        case .running, .done: logPanel
        case .scanning, .idle:
            Bezel(radius: 30, padding: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<6, id: \.self) { _ in RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.05)).frame(height: 18) }
                }.frame(maxWidth: .infinity)
            }
        case .ready: groups
        }
    }

    var groups: some View {
        Scroller {
            Bezel(radius: 30, padding: 0) {
                VStack(spacing: 0) {
                    ForEach(store.preview.groups) { g in group(g) }
                    if store.preview.groups.isEmpty {
                        Text("Nothing to clean right now.").font(T.sans(15)).foregroundStyle(T.mute).padding(28)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    func group(_ g: CleanGroup) -> some View {
        let on = !store.off.contains(g.name)
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                CheckBox(isOn: Binding(get: { on }, set: { v in if v { store.off.remove(g.name) } else { store.off.insert(g.name) } }))
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.name.uppercased()).font(T.mono(11)).tracking(2).foregroundStyle(on ? T.soft : T.faint)
                    Text(CleanKnowledge.groupBlurb[g.name] ?? "").font(T.sans(12)).foregroundStyle(T.dim)
                }
                Spacer()
                Text(Fmt.bytes(g.bytes)).font(T.mono(13)).foregroundStyle(on ? T.bone : T.faint)
            }.padding(.horizontal, 26).padding(.top, 22).padding(.bottom, 10)

            ForEach(g.items) { item in row(item, groupOn: on) }
        }
    }

    func row(_ item: CleanItem, groupOn: Bool) -> some View {
        let ex = CleanKnowledge.explain(item.name)
        let isTrash = item.name.lowercased() == "trash"
        let open = store.opened == item.id
        let active = item.reviewOnly ? false : (isTrash ? store.trashOn : groupOn)
        return VStack(spacing: 0) {
            Divider().overlay(T.hair)
            HStack(spacing: 12) {
                if isTrash {
                    CheckBox(isOn: Binding(get: { store.trashOn }, set: { store.trashOn = $0 }))
                } else { Color.clear.frame(width: 16, height: 16) }
                Text(item.name).font(T.sans(15, .medium)).foregroundStyle(active || item.reviewOnly ? T.bone : T.faint)
                if let c = item.count { Text("\(c) item\(c == 1 ? "" : "s")").font(T.mono(12)).foregroundStyle(T.dim) }
                SafetyTag(safety: item.reviewOnly ? .caution : (isTrash ? .caution : ex.safety))
                Spacer()
                Text(item.reviewOnly ? "review" : (item.bytes.map(Fmt.bytes) ?? "—")).font(T.mono(13)).foregroundStyle(active ? T.bone : T.faint)
                Button(open ? "Close" : "Why?") { withAnimation(T.spring) { store.opened = open ? nil : item.id } }
                    .buttonStyle(.plain).font(T.sans(12, .medium))
                    .foregroundStyle(open ? T.bg : T.soft).padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(open ? T.bone : Color.white.opacity(0.05)))
            }.padding(.horizontal, 26).padding(.vertical, 13).padding(.leading, isTrash ? 0 : 0)
            if open {
                HStack(alignment: .top, spacing: 0) {
                    col("What it is", item.reviewOnly ? "mo only points at this one. Review it yourself; MacCare won't clean it from here." : ex.what, T.dim)
                    col("+ You gain", ex.gain, T.safe).overlay(alignment: .leading) { Rectangle().fill(T.hair).frame(width: 1) }
                    col("− You give up", ex.lose, T.risky).overlay(alignment: .leading) { Rectangle().fill(T.hair).frame(width: 1) }
                }
                .padding(.horizontal, 26).padding(.bottom, 18)
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }

    func col(_ title: String, _ body: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(T.mono(10)).tracking(1.8).foregroundStyle(color)
            Text(body).font(T.sans(14)).lineSpacing(3).foregroundStyle(T.soft).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 18).frame(maxWidth: .infinity, alignment: .leading)
    }

    var logPanel: some View {
        Bezel(radius: 30, padding: 26) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: store.phase == .running ? "mo clean · live output" : "mo clean · finished")
                Scroller {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(store.log.enumerated()), id: \.offset) { _, l in
                            Text(l).font(T.mono(12)).foregroundStyle(l.hasPrefix("✓") ? T.safe : T.mute).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }.frame(minHeight: 520)
            }
        }
    }
}

struct TickBar: View {
    var value: Double
    var body: some View {
        GeometryReader { g in
            let n = 64
            HStack(spacing: 3) {
                ForEach(0..<n, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Double(i) < value * Double(n) ? T.accent : T.bone.opacity(0.12))
                }
            }
        }
        .animation(T.spring, value: value)
    }
}
