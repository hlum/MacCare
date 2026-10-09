import Foundation

/// The cleanX registry, as data. Text is cleanX's own.
struct XcodeItem: Identifiable {
    enum Kind { case paths, testClones, unavailable, simulators, runtimes, deviceSupport, archives, xcodeApps }
    let id: String
    let name: String
    let kind: Kind
    let safety: Safety
    let paths: [String]          // for display and for .paths cleaning
    let symbol: String
    let what: String
    let gain: String
    let lose: String
    var picker: Bool { [.simulators, .runtimes, .deviceSupport, .archives, .xcodeApps].contains(kind) }
}

enum XcodeData {
    static let dev = NSHomeDirectory() + "/Library/Developer"
    static let caches = NSHomeDirectory() + "/Library/Caches"
    static let logs = NSHomeDirectory() + "/Library/Logs"

    static let supportRoots = ["iOS", "watchOS", "tvOS", "visionOS", "macOS"].map { "\(dev)/Xcode/\($0) DeviceSupport" }

    static let items: [XcodeItem] = [
        .init(id: "derived", name: "DerivedData", kind: .paths, safety: .safe, paths: ["\(dev)/Xcode/DerivedData"], symbol: "folder",
              what: "Xcode's build folder: compiled object files, indexes, module caches and build products for every project you've ever opened, one folder per project. Xcode never cleans it up by itself.",
              gain: "Usually one of the biggest wins. It also fixes a lot of weird build, indexing and autocomplete problems.",
              lose: "The next build of each project is a full (slower) build and Xcode re-indexes. Nothing is lost."),
        .init(id: "testclones", name: "Parallel testing clones", kind: .testClones, safety: .safe, paths: ["\(dev)/XCTestDevices"], symbol: "iphone",
              what: "Copies of simulators that Xcode makes when it runs tests in parallel (one clone per test worker). They're meant to be temporary but they pile up, often to tens or even hundreds of GB.",
              gain: "Often huge, and useless once your tests have finished.",
              lose: "None. Xcode makes fresh clones the next time you run parallel tests."),
        .init(id: "unavail", name: "Unavailable simulators", kind: .unavailable, safety: .safe, paths: ["\(dev)/CoreSimulator/Devices"], symbol: "exclamationmark.triangle",
              what: "Simulators whose iOS runtime isn't installed anymore, usually left behind after an Xcode update. They can't boot.",
              gain: "Removes dead devices along with the app data stuck inside them.",
              lose: "None. They can't run without their old runtime anyway."),
        .init(id: "sims", name: "Simulator devices", kind: .simulators, safety: .caution, paths: ["\(dev)/CoreSimulator/Devices"], symbol: "iphone.gen3",
              what: "Each simulator is a full virtual device with its own installed apps, data, photos, keychain and settings. Xcode creates a whole set of devices for every runtime you install.",
              gain: "Simulators with apps and media in them can take several GB each, and most people only use one or two.",
              lose: "Everything inside a deleted simulator is gone: installed apps, login state, test data. You can recreate empty devices any time in Xcode › Window › Devices and Simulators."),
        .init(id: "runtimes", name: "Simulator runtimes", kind: .runtimes, safety: .caution, paths: ["managed by Xcode (xcrun simctl runtime)"], symbol: "display",
              what: "The actual iOS / watchOS / tvOS / visionOS system images that simulators boot. Each one is roughly 5–10 GB.",
              gain: "Removing OS versions you don't test on frees a lot of space.",
              lose: "Simulators that use that runtime become unavailable. If you need that version again you'll have to re-download several GB from Xcode › Settings › Components."),
        .init(id: "devicesupport", name: "Device support files", kind: .deviceSupport, safety: .safe, paths: supportRoots, symbol: "cpu",
              what: "Debug symbols that Xcode copies from each physical device you plug in, once per device model and OS version, so it can debug on it and symbolicate crashes. That's about 3–7 GB each time.",
              gain: "Old OS versions you no longer run are just dead weight.",
              lose: "The next time you connect a device on that OS, Xcode spends a few minutes on “Preparing device” to copy the symbols again."),
        .init(id: "previews", name: "SwiftUI Previews", kind: .paths, safety: .safe, paths: ["\(dev)/Xcode/UserData/Previews"], symbol: "play",
              what: "Hidden simulators and builds that power SwiftUI / #Preview canvases.",
              gain: "Can be several GB, and clearing it also fixes a stuck or crashing preview canvas.",
              lose: "Previews take longer to appear the first time afterwards."),
        .init(id: "xcodecache", name: "Xcode & simulator caches", kind: .paths, safety: .safe,
              paths: ["\(caches)/com.apple.dt.Xcode", "\(dev)/Xcode/DocumentationCache", "\(dev)/Xcode/Products", "\(dev)/CoreSimulator/Caches"], symbol: "wind",
              what: "Miscellaneous caches: Xcode's own app cache, the downloaded documentation cache, exported products, and the simulator's per-user caches.",
              gain: "Safe housekeeping that sometimes fixes glitches too.",
              lose: "Xcode rebuilds them as needed, so the first launch or docs lookup may be a bit slower."),
        .init(id: "logs", name: "Simulator & device logs", kind: .paths, safety: .safe,
              paths: ["\(logs)/CoreSimulator", "\(dev)/Xcode/iOS Device Logs", "\(dev)/Xcode/watchOS Device Logs"], symbol: "clock.arrow.circlepath",
              what: "Log files written by the simulator, plus logs pulled off physical devices.",
              gain: "Pure clutter for most people.",
              lose: "You lose old logs you might have wanted for debugging."),
        .init(id: "spm", name: "Swift Package Manager cache", kind: .paths, safety: .safe, paths: ["\(caches)/org.swift.swiftpm"], symbol: "shippingbox",
              what: "Global cache of cloned Swift packages, shared by all your projects.",
              gain: "Frees space taken by packages you no longer use.",
              lose: "Packages are downloaded again the next time a project resolves them (you need internet for that)."),
        .init(id: "cocoapods", name: "CocoaPods cache", kind: .paths, safety: .safe, paths: ["\(caches)/CocoaPods"], symbol: "shippingbox",
              what: "Downloaded pod sources and specs cached by CocoaPods.",
              gain: "Frees space. Your projects' own Pods folders aren't touched.",
              lose: "The next “pod install” downloads pods again."),
        .init(id: "carthage", name: "Carthage cache", kind: .paths, safety: .safe, paths: ["\(caches)/org.carthage.CarthageKit"], symbol: "shippingbox",
              what: "Downloaded dependencies and binaries cached by Carthage.",
              gain: "Frees space. Your projects' Carthage folders aren't touched.",
              lose: "The next “carthage bootstrap” downloads everything again."),
        .init(id: "archives", name: "Archives", kind: .archives, safety: .risky, paths: ["\(dev)/Xcode/Archives"], symbol: "archivebox",
              what: "Every build you've made with Product › Archive, i.e. what you upload to TestFlight or the App Store. Each one contains the app plus its dSYM debug symbols.",
              gain: "Archives of versions nobody runs anymore can go.",
              lose: "dSYMs are what turn crash reports from released versions into readable stack traces, and you can't recreate them for a given build. Keep archives for any version still in users' hands."),
        .init(id: "xcodeapps", name: "Other Xcode versions", kind: .xcodeApps, safety: .caution, paths: ["/Applications/Xcode*.app (never the active one)"], symbol: "chevron.left.forwardslash.chevron.right",
              what: "Extra copies of Xcode (betas, old versions) in /Applications, each one 8–12+ GB. The Xcode currently selected with xcode-select is never listed.",
              gain: "A huge win if you've kept old or beta Xcodes around.",
              lose: "If a project needs that version again you'll have to re-download it from developer.apple.com (slow)."),
    ]
}
