import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Graphite & signal. One accent, warm neutrals.
enum T {
    static let bg = Color(hex: 0x0D0D0C)
    static let panel = Color(hex: 0x151513)
    static let bone = Color(hex: 0xEDEBE4)
    static let soft = Color(hex: 0xC9C6BC)
    static let mute = Color(hex: 0x9A978C)
    static let dim = Color(hex: 0x85827A)
    static let faint = Color(hex: 0x6E6B62)
    static let accent = Color(hex: 0xFF5F1F)
    static let accentSoft = Color(hex: 0xFF8A57)
    static let safe = Color(hex: 0x8FD694)
    static let caution = Color(hex: 0xF2C14E)
    static let risky = Color(hex: 0xFF8A80)
    static let hair = Color.white.opacity(0.06)

    /// The one easing curve used everywhere.
    static let spring = Animation.spring(response: 0.55, dampingFraction: 0.82)
    static let ease = Animation.timingCurve(0.32, 0.72, 0, 1, duration: 0.5)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Doppelrand: a hairline outer shell around an inner panel.
struct Bezel<Content: View>: View {
    var radius: CGFloat = 28
    var padding: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius - 5, style: .continuous)
                    .fill(T.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius - 5, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.07), .clear],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    )
            )
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.white.opacity(0.025))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(T.hair, lineWidth: 1))
            )
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(T.mono(11)).tracking(2.2).foregroundStyle(T.dim)
    }
}

/// Pill with a nested trailing icon circle.
struct PillButtonStyle: ButtonStyle {
    var filled = true
    var danger = false
    var icon: String? = "arrow.up.right"

    func makeBody(configuration: Configuration) -> some View {
        let fg = filled ? Color(hex: 0x140A04) : T.bone
        let bg = filled ? (danger ? T.risky : T.accent) : Color.white.opacity(0.06)
        HStack(spacing: 14) {
            configuration.label.font(T.sans(15, .semibold))
            if let icon {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(fg.opacity(0.14)))
            }
        }
        .foregroundStyle(fg)
        .padding(.leading, 22).padding(.trailing, icon == nil ? 22 : 6).padding(.vertical, 6)
        .frame(minHeight: 46)
        .background(Capsule().fill(bg))
        .shadow(color: filled && !danger ? T.accent.opacity(0.35) : .clear, radius: 18, y: 8)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(T.spring, value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(T.sans(13, .medium)).foregroundStyle(T.soft)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.09 : 0.05)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(T.spring, value: configuration.isPressed)
    }
}

/// SAFE / REVIEW / RISKY tag.
enum Safety: String {
    case safe, caution, risky
    var label: String { switch self { case .safe: "SAFE"; case .caution: "REVIEW"; case .risky: "RISKY" } }
    var color: Color { switch self { case .safe: T.safe; case .caution: T.caution; case .risky: T.risky } }
}

struct SafetyTag: View {
    let safety: Safety
    var body: some View {
        Text("● \(safety.label)")
            .font(T.mono(10)).tracking(1.2).foregroundStyle(safety.color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(safety.color.opacity(0.27), lineWidth: 1))
    }
}

// MARK: - snapshot support

private struct SnapshotKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True while rendering offscreen with ImageRenderer, which can't draw ScrollView or AppKit-backed views.
    var snapshot: Bool { get { self[SnapshotKey.self] } set { self[SnapshotKey.self] = newValue } }
}

/// A ScrollView that falls back to plain content when rendering a snapshot.
struct Scroller<Content: View>: View {
    @Environment(\.snapshot) private var snapshot
    @ViewBuilder var content: () -> Content
    var body: some View {
        if snapshot { content().frame(maxHeight: .infinity, alignment: .top) } else { ScrollView { content() } }
    }
}

/// Our own checkbox: consistent look, and renderable in snapshots.
struct CheckBox: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { withAnimation(T.spring) { isOn.toggle() } } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isOn ? T.accent : Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(isOn ? Color.clear : Color.white.opacity(0.22), lineWidth: 1))
                .overlay(Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: 0x140A04)).opacity(isOn ? 1 : 0))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton).accessibilityValue(isOn ? "checked" : "unchecked")
    }
}

struct SwitchToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button { withAnimation(T.spring) { isOn.toggle() } } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? T.accent : Color.white.opacity(0.14)).frame(width: 36, height: 20)
                Circle().fill(isOn ? Color(hex: 0x140A04) : T.bone).frame(width: 16, height: 16).padding(2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isButton).accessibilityValue(isOn ? "on" : "off")
    }
}

/// Small activity indicator that also renders in snapshots.
struct Spinner: View {
    @Environment(\.snapshot) private var snapshot
    var body: some View {
        if snapshot { Circle().fill(T.accent).frame(width: 8, height: 8) } else { ProgressView().controlSize(.small).tint(T.accent) }
    }
}
