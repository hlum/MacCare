import SwiftUI

/// Shown when the `mo` engine isn't installed.
struct MissingMoView: View {
    var retry: () -> Void
    @State private var copied = false
    private let command = "brew install mole"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: "One thing first")
            Text("MacCare needs mo").font(.system(size: 72, weight: .medium)).tracking(-4).foregroundStyle(T.bone).padding(.top, 24)
            Text("MacCare is the interface; the cleaning itself is done by the free, open-source mo command (Mole, by tw93). Install it once with Homebrew, then come back.")
                .font(T.sans(17)).lineSpacing(4).foregroundStyle(T.mute).frame(maxWidth: 520, alignment: .leading).padding(.top, 20)
            Bezel(radius: 24, padding: 16) {
                HStack {
                    Text(command).font(T.mono(15)).foregroundStyle(T.bone).textSelection(.enabled)
                    Spacer()
                    Button(copied ? "Copied" : "Copy") {
                        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(command, forType: .string); copied = true
                    }.buttonStyle(QuietButtonStyle())
                }
            }.frame(maxWidth: 520).padding(.top, 32)
            HStack(spacing: 16) {
                Button { retry() } label: { Text("I installed it") }.buttonStyle(PillButtonStyle(icon: "arrow.clockwise"))
                Link("No Homebrew? See brew.sh", destination: URL(string: "https://brew.sh")!).font(T.sans(14)).foregroundStyle(T.accent)
            }.padding(.top, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(48)
    }
}
