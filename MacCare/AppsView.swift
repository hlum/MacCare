import SwiftUI

struct AppsView: View {
    @Environment(AppsStore.self) private var store
    @State private var confirming = false
    @Environment(\.snapshot) private var snapshot

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            left.frame(width: 380)
            VStack(alignment: .leading, spacing: 16) {
                header
                switch store.tab {
                case .uninstall: appList
                case .login: fileList(store.agents, empty: "No login items in ~/Library/LaunchAgents.", action: nil)
                case .installers: fileList(store.installers, empty: "No installers in Downloads or Desktop.", action: "Move chosen to Trash")
                }
            }
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(maxWidth: 1320).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.load() }
        .confirmationDialog("Uninstall \(store.selected?.name ?? "")?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Uninstall", role: .destructive) { store.uninstall() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The app and the files listed will be removed. Files shared with other installed apps are kept.") }
    }

    // MARK: left

    var left: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.tab == .uninstall, let app = store.selected {
                Eyebrow(text: "Uninstall · \(app.bundleId ?? "app")")
                HStack(spacing: 18) {
                    AppIcon(path: app.path, name: app.name, size: 64)
                    Text(app.name).font(.system(size: 44, weight: .medium)).tracking(-2.5).foregroundStyle(T.bone).lineLimit(2).minimumScaleFactor(0.6)
                }.padding(.top, 26)
                Text("Removes the app and everything it left in your Library.").font(T.sans(16)).foregroundStyle(T.mute).lineSpacing(3).padding(.top, 16).frame(maxWidth: 330, alignment: .leading)

                VStack(spacing: 0) {
                    Divider().overlay(T.hair)
                    if store.previewing { HStack { ProgressView().controlSize(.small); Text("LISTING FILES").font(T.mono(11)).tracking(2).foregroundStyle(T.dim) }.padding(.vertical, 18) }
                    ForEach(store.preview) { f in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(f.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")).font(T.mono(11)).foregroundStyle(T.mute).lineLimit(2).truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(Fmt.bytes(f.bytes)).font(T.mono(12)).foregroundStyle(T.bone)
                        }.padding(.vertical, 10)
                        Divider().overlay(T.hair)
                    }
                }.padding(.top, 24)

                HStack(spacing: 14) {
                    Button { confirming = true } label: { Text("Uninstall · \(Fmt.bytes(store.previewBytes))") }
                        .buttonStyle(PillButtonStyle(icon: "trash")).disabled(store.previewing || store.running || store.preview.isEmpty || !store.singleMatch)
                    if let a = store.selected { Button("Reveal") { store.reveal(a.path) }.buttonStyle(QuietButtonStyle()) }
                }.padding(.top, 28)
                if let m = store.message { Text(m).font(T.sans(13)).foregroundStyle(T.risky).padding(.top, 14).frame(maxWidth: 340, alignment: .leading) }
                if store.running || !store.log.isEmpty {
                    Text(store.log.suffix(4).joined(separator: "\n")).font(T.mono(11)).foregroundStyle(T.dim).padding(.top, 16).frame(maxWidth: 340, alignment: .leading)
                }
            } else {
                Eyebrow(text: store.tab.rawValue)
                Text(store.tab == .installers ? "\(store.installers.count)" : store.tab == .login ? "\(store.agents.count)" : "—")
                    .font(.system(size: 120, weight: .medium)).tracking(-7).foregroundStyle(T.bone).padding(.top, 26)
                Text(store.tab == .installers ? "disk images and packages left in Downloads and Desktop. They go to the Trash, so you can put them back."
                     : "background items that start with your Mac. MacCare only lists them for now; open the folder to remove one.")
                    .font(T.sans(16)).lineSpacing(4).foregroundStyle(T.mute).frame(maxWidth: 330, alignment: .leading).padding(.top, 20)
            }
            Spacer()
        }
        .animation(T.spring, value: store.selected)
    }

    // MARK: right

    var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                ForEach(AppsStore.Tab.allCases, id: \.self) { t in
                    Button { withAnimation(T.spring) { store.tab = t } } label: {
                        Text(t.rawValue).font(T.sans(13, .medium)).foregroundStyle(store.tab == t ? T.bg : T.mute)
                            .padding(.horizontal, 16).padding(.vertical, 7).background(Capsule().fill(store.tab == t ? T.bone : .clear))
                    }.buttonStyle(.plain)
                }
            }.padding(4).background(Capsule().fill(Color.white.opacity(0.04)).overlay(Capsule().strokeBorder(T.hair)))
            Spacer()
            if store.tab == .uninstall {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(T.dim)
                    if snapshot { Text("Search \(store.apps.count) apps").font(T.sans(13)).foregroundStyle(T.dim).frame(width: 150, alignment: .leading) }
                    else { TextField("Search \(store.apps.count) apps", text: Binding(get: { store.query }, set: { store.query = $0 })).textFieldStyle(.plain).font(T.sans(13)).frame(width: 150) }
                }.padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Color.white.opacity(0.04)).overlay(Capsule().strokeBorder(T.hair)))
            }
        }
    }

    var appList: some View {
        Scroller {
            Bezel(radius: 30, padding: 0) {
                LazyVStack(spacing: 0) {
                    if store.loading { ProgressView().padding(40) }
                    ForEach(store.filtered) { a in
                        let on = store.selected == a
                        Button { store.select(a) } label: {
                            HStack(spacing: 14) {
                                AppIcon(path: a.path, name: a.name, size: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(a.name).font(T.sans(15, .medium)).foregroundStyle(T.bone)
                                    Text(a.bundleId ?? "").font(T.mono(11)).foregroundStyle(T.dim)
                                }
                                Spacer()
                                Text(a.size).font(T.mono(13)).foregroundStyle(on ? T.bone : T.mute)
                            }
                            .padding(.horizontal, 24).padding(.vertical, 11).contentShape(Rectangle())
                            .background(on ? T.accent.opacity(0.08) : .clear)
                            .overlay(alignment: .leading) { if on { Rectangle().fill(T.accent).frame(width: 2) } }
                        }.buttonStyle(.plain)
                        Divider().overlay(T.hair)
                    }
                }
            }
        }.scrollIndicators(.hidden)
    }

    func fileList(_ rows: [FileRow], empty: String, action: String?) -> some View {
        Scroller {
            Bezel(radius: 30, padding: 0) {
                VStack(spacing: 0) {
                    if rows.isEmpty { Text(empty).font(T.sans(15)).foregroundStyle(T.mute).padding(28) }
                    ForEach(rows) { r in
                        let on = store.chosen.contains(r.id)
                        HStack(spacing: 14) {
                            if action != nil {
                                Button { if on { store.chosen.remove(r.id) } else { store.chosen.insert(r.id) } } label: {
                                    Image(systemName: on ? "checkmark.square.fill" : "square").foregroundStyle(on ? T.accent : T.faint)
                                }.buttonStyle(.plain)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(r.title).font(T.sans(15, .medium)).foregroundStyle(T.bone).lineLimit(1)
                                Text(r.subtitle).font(T.mono(11)).foregroundStyle(T.dim).lineLimit(1).truncationMode(.middle)
                            }
                            Spacer()
                            if r.bytes > 0 { Text(Fmt.bytes(r.bytes)).font(T.mono(13)).foregroundStyle(T.mute) }
                            Button("Reveal") { store.reveal(r.path) }.buttonStyle(QuietButtonStyle())
                        }.padding(.horizontal, 24).padding(.vertical, 12)
                        Divider().overlay(T.hair)
                    }
                    if let action, !rows.isEmpty {
                        HStack { Spacer(); Button(action) { store.trashChosen() }.buttonStyle(PillButtonStyle(icon: nil)).disabled(store.chosen.isEmpty).opacity(store.chosen.isEmpty ? 0.4 : 1) }.padding(18)
                    }
                }
            }
        }.scrollIndicators(.hidden)
    }
}
