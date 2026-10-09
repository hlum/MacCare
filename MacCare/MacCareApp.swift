import SwiftUI

@main
struct MacCareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    // Stores live here so switching tabs never throws away a scan, or a run in progress.
    @State private var status = StatusStore()
    @State private var clean = CleanStore()
    @State private var disk = AnalyzeStore()
    @State private var xcode = XcodeStore()
    @State private var apps = AppsStore()
    @State private var optimize = OptimizeStore()

    var body: some Scene {
        Window("MacCare", id: "main") {
            RootView()
                .frame(minWidth: 1080, minHeight: 720)
                .preferredColorScheme(.dark)
                .environment(status).environment(clean).environment(disk)
                .environment(xcode).environment(apps).environment(optimize)
                .onAppear { status.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 860)

        MenuBarExtra {
            MenuBarPopover().environment(status)
        } label: {
            MenuBarLabel().environment(status)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var sigSources: [DispatchSourceSignal] = []

    /// True when the system opened us at login (Apple event 'lgit'). Not guaranteed on every macOS version.
    static var launchedAsLoginItem: Bool {
        NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == AEKeyword(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Repair a whitelist block left behind if the app died mid-clean last time.
        CleanStore.recoverLeftoverWhitelist()
        if Self.launchedAsLoginItem {
            DispatchQueue.main.async { NSApp.windows.filter { $0.canBecomeMain }.forEach { $0.close() } }
        }
        // Quit via SIGTERM/SIGINT (kill, Xcode Stop) skips applicationWillTerminate, so clean up here too.
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { Terminator.shared.killAll(); CleanStore.recoverLeftoverWhitelist(); exit(0) }
            src.resume()
            sigSources.append(src)
        }
    }

    // The menu bar item keeps running after the window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard Activity.shared.busy else { return .terminateNow }
        let a = NSAlert()
        a.messageText = "A cleanup is still running"
        a.informativeText = "Quitting now stops it partway through. Files already removed stay removed."
        a.addButton(withTitle: "Keep running"); a.addButton(withTitle: "Quit anyway")
        return a.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        Terminator.shared.killAll()
        CleanStore.recoverLeftoverWhitelist()
    }
}
