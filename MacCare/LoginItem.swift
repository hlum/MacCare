import SwiftUI
import ServiceManagement

/// "Start at login" through SMAppService (macOS 13+). The user can also see and remove it in System Settings › General › Login Items.
enum LoginItem {
    static var enabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func set(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }
}

struct LoginToggle: View {
    @State private var on = LoginItem.enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Image(systemName: "power").frame(width: 18).foregroundStyle(T.mute)
                Text("Start at login").font(T.sans(14)).foregroundStyle(T.bone)
                Spacer()
                SwitchToggle(isOn: Binding(get: { on }, set: { v in
                    do { try LoginItem.set(v); error = nil } catch { self.error = error.localizedDescription }
                    on = LoginItem.enabled || LoginItem.needsApproval
                }))
            }.padding(.vertical, 7)
            if LoginItem.needsApproval { Text("Allow MacCare in System Settings › General › Login Items.").font(T.sans(11)).foregroundStyle(T.caution) }
            if let error { Text(error).font(T.sans(11)).foregroundStyle(T.risky) }
        }
        .onAppear { on = LoginItem.enabled }
    }
}
