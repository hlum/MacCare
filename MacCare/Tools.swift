import SwiftUI
import AppKit
import IOKit.pwr_mgt
import CoreAudio
import CoreMediaIO
import Observation

@Observable
final class ToolsModel {
    static let shared = ToolsModel()

    var keepAwake = false { didSet { setAwake(keepAwake) } }
    var cameraOn = false
    var micOn = false
    private var assertion: IOPMAssertionID = 0
    private var timer: Timer?
    private var cleanWindow: NSWindow?
    private var keyMonitor: Any?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    // MARK: keep screen on
    private func setAwake(_ on: Bool) {
        if on {
            IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "MacCare: keep screen on" as CFString, &assertion)
        } else if assertion != 0 {
            IOPMAssertionRelease(assertion); assertion = 0
        }
    }

    // MARK: privacy check
    func poll() { cameraOn = Self.cameraRunning(); micOn = Self.micRunning() }

    static func micRunning() -> Bool {
        var devID = AudioObjectID(kAudioObjectUnknown), size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devID) == noErr, devID != kAudioObjectUnknown else { return false }
        var running: UInt32 = 0; size = UInt32(MemoryLayout<UInt32>.size)
        var a2 = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        return AudioObjectGetPropertyData(devID, &a2, 0, nil, &size, &running) == noErr && running != 0
    }

    static func cameraRunning() -> Bool {
        var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == noErr, size > 0 else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &used, &ids) == noErr else { return false }
        for id in ids {
            var r: UInt32 = 0, rs = UInt32(MemoryLayout<UInt32>.size), u: UInt32 = 0
            var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere), mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal), mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            if CMIOObjectGetPropertyData(id, &a, 0, nil, rs, &u, &r) == noErr, r != 0 { return true }
        }
        return false
    }

    // MARK: clean screen
    func startCleanScreen() {
        guard cleanWindow == nil, let screen = NSScreen.main else { return }
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver; w.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.92, blue: 0.89, alpha: 1)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]; w.isReleasedWhenClosed = false
        let label = NSTextField(labelWithString: "Wipe the screen and keyboard.   Press Esc to exit.")
        label.font = .monospacedSystemFont(ofSize: 14, weight: .regular); label.textColor = NSColor(white: 0.45, alpha: 1)
        label.sizeToFit(); label.frame.origin = CGPoint(x: (screen.frame.width - label.frame.width) / 2, y: 60)
        w.contentView?.addSubview(label)
        NSApp.activate(ignoringOtherApps: true); w.makeKeyAndOrderFront(nil); NSCursor.hide()
        cleanWindow = w
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] e in
            if e.keyCode == 53 { self?.endCleanScreen() }
            return nil          // swallow keys so wiping the keyboard types nothing
        }
    }

    func endCleanScreen() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        cleanWindow?.orderOut(nil); cleanWindow = nil; NSCursor.unhide()
    }
}

struct ToolsList: View {
    @State private var tools = ToolsModel.shared

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 12) {
                Image(systemName: "display").frame(width: 18).foregroundStyle(T.mute)
                Text("Keep screen on").font(T.sans(14)).foregroundStyle(T.bone)
                Spacer()
                SwitchToggle(isOn: Binding(get: { tools.keepAwake }, set: { tools.keepAwake = $0 }))
            }.padding(.vertical, 7)
            Button { tools.startCleanScreen() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.tv").frame(width: 18).foregroundStyle(T.mute)
                    Text("Clean screen").font(T.sans(14)).foregroundStyle(T.bone)
                    Spacer(); Text("ESC TO EXIT").font(T.mono(10)).foregroundStyle(T.faint)
                }.padding(.vertical, 7).contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled").frame(width: 18).foregroundStyle(T.mute)
                Text("Camera & mic").font(T.sans(14)).foregroundStyle(T.bone)
                Spacer()
                let busy = tools.cameraOn || tools.micOn
                Text(busy ? "● \([tools.cameraOn ? "CAMERA" : nil, tools.micOn ? "MIC" : nil].compactMap { $0 }.joined(separator: " + "))" : "● IDLE")
                    .font(T.mono(10)).foregroundStyle(busy ? T.risky : T.safe)
            }.padding(.vertical, 7)
        }
    }
}
