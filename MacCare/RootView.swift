import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case clean = "Clean", apps = "Apps", optimize = "Optimize", xcode = "Xcode", disk = "Disk", status = "Status"
    var id: String { rawValue }
}

struct RootView: View {
    @State private var section: Page = Page(rawValue: UserDefaults.standard.string(forKey: "section") ?? "") ?? .clean
    @State private var version = "…"
    @Namespace private var pill
    @State private var moInstalled = Mo.installed
    @Environment(StatusStore.self) private var status

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                TopNav(section: $section, pill: pill)
                Group {
                    if !moInstalled { MissingMoView(retry: { moInstalled = Mo.installed; if moInstalled { status.stop(); status.start() } }) }
                    else { switch section {
                    case .clean: CleanView(openXcode: { withAnimation(T.spring) { section = .xcode } })
                    case .apps: AppsView()
                    case .optimize: OptimizeView()
                    case .xcode: XcodeView()
                    case .status: StatusView()
                    case .disk: AnalyzeView()
                    default:
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: section.rawValue)
                            Text("mo \(version)").font(.system(size: 72, weight: .medium)).tracking(-3)
                                .foregroundStyle(T.bone)
                            Text(Mo.installed ? "Engine found at \(Mo.path)" : "mo not found. Run: brew install mole")
                                .font(T.sans(15)).foregroundStyle(T.mute)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(48)
                    } }
                }
            }
        }
        .task { version = await Mo.version() }
    }
}

struct TopNav: View {
    @Environment(\.snapshot) private var snapshot
    @Binding var section: Page
    var pill: Namespace.ID

    var body: some View {
        ZStack {
            HStack(spacing: 2) {
                ForEach(Page.allCases) { s in
                    Button { withAnimation(T.spring) { section = s } } label: {
                        Text(s.rawValue)
                            .font(T.sans(13, .medium))
                            .foregroundStyle(section == s ? T.bg : T.mute)
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background {
                                if section == s { Capsule().fill(T.bone).matchedGeometryEffect(id: "pill", in: pill) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.white.opacity(0.04)).overlay(Capsule().strokeBorder(T.hair)))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 10)
        .background { if !snapshot { WindowDragArea() } }
    }
}

/// Lets the hidden title bar area still drag the window.
struct WindowDragArea: NSViewRepresentable {
    final class V: NSView { override var mouseDownCanMoveWindow: Bool { true } }
    func makeNSView(context: Context) -> NSView { V() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
