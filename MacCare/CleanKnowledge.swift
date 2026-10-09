import Foundation

/// Plain-language "what is this / what do I gain / what do I give up" for the things `mo clean` reports.
/// Matches on lowercase substrings of the item name. First hit wins, so order matters.
struct Explanation {
    var safety: Safety
    var what: String
    var gain: String
    var lose: String
}

enum CleanKnowledge {
    private static let table: [(keys: [String], e: Explanation)] = [
        (["trash"], .init(safety: .caution,
            what: "Files you already moved to the Trash. They still take up space until the Trash is emptied.",
            gain: "The space comes back immediately.",
            lose: "This can't be undone. Anything in the Trash is gone for good.")),
        (["service worker"], .init(safety: .caution,
            what: "Offline data that websites and web apps store in Chrome so they can work without a connection.",
            gain: "Frees space used by sites you rarely visit.",
            lose: "Web apps that work offline (docs, chat, mail) may need to reload their data once.")),
        (["sticker", "attachment", "messages"], .init(safety: .caution,
            what: "Previews and thumbnails the Messages app saved so conversations scroll quickly.",
            gain: "Frees space taken by old conversations' previews.",
            lose: "Old conversations load their previews again when you scroll back to them.")),
        (["leaked browser", "browser profile"], .init(safety: .safe,
            what: "Temporary browser profiles left behind by automation tools and crashed test runs.",
            gain: "Removes clutter nothing is using.",
            lose: "Nothing, unless a test run is still using one right now.")),
        (["homebrew"], .init(safety: .safe,
            what: "Downloaded installers and old versions of packages that Homebrew keeps after upgrading.",
            gain: "Frees space from versions you've already moved past.",
            lose: "Homebrew downloads a package again if you reinstall or roll back.")),
        (["npm", "pnpm", "yarn", "pip", "uv ", "uv cache", "cargo", "gradle", "cocoapods", "carthage", "github cli", "package"], .init(safety: .safe,
            what: "Copies of libraries and tools your developer commands downloaded, kept so the next install is fast.",
            gain: "Frees space from projects and versions you no longer use.",
            lose: "The next install or build re-downloads what it needs, so it's slower and needs internet.")),
        (["chrome", "safari", "firefox", "edge", "brave", "arc ", "browser", "googleupdater"], .init(safety: .safe,
            what: "Pages, images and scripts your browser saved so sites you've visited load faster.",
            gain: "Often the biggest single item after app caches.",
            lose: "Sites load a little slower the first time you open them again. Logins and bookmarks are not touched.")),
        (["siri", "spotlight", "parsecd", "suggestion"], .init(safety: .safe,
            what: "The cache behind Siri Suggestions and Spotlight's web results.",
            gain: "Clears out stale suggestions.",
            lose: "Suggestions are less relevant for a short while as it rebuilds.")),
        (["maps", "geod", "geo"], .init(safety: .safe,
            what: "Map tiles and location data saved so places you've looked at load instantly.",
            gain: "Frees space taken by areas you won't look at again.",
            lose: "Maps downloads tiles again as you browse, so it's slower at first.")),
        (["help"], .init(safety: .safe,
            what: "Cached pages from macOS Help and the help books inside apps.",
            gain: "Rarely used, so it's easy space.",
            lose: "Help pages load a little slower the next time you open them.")),
        (["media analysis"], .init(safety: .safe,
            what: "Temporary files from the on-device analysis Photos does to find faces and objects.",
            gain: "Frees temporary working files.",
            lose: "Photos may redo some analysis in the background.")),
        (["logs", "log "], .init(safety: .safe,
            what: "Diagnostic logs apps write while they run.",
            gain: "Pure clutter for most people.",
            lose: "Old logs you might want when chasing down a crash are gone.")),
        (["temp", "tmp"], .init(safety: .safe,
            what: "Scratch files that apps created while working and never cleaned up.",
            gain: "Frees space nothing is relying on.",
            lose: "An app that is mid-task may redo a little work.")),
        (["cache"], .init(safety: .safe,
            what: "Files an app keeps so it can open and load faster. Apps rarely clean these up themselves.",
            gain: "Frees space and can fix apps that act up because of a stale cache.",
            lose: "The app is a little slower the first time it runs while it rebuilds the cache.")),
    ]

    static let fallback = Explanation(safety: .safe,
        what: "Files that mo identified as safe to regenerate.",
        gain: "Frees disk space.",
        lose: "Whatever app owns them may rebuild them the next time it runs.")

    static func explain(_ name: String) -> Explanation {
        let n = name.lowercased()
        return table.first { $0.keys.contains { n.contains($0) } }?.e ?? fallback
    }

    static let groupBlurb: [String: String] = [
        "User essentials": "Caches, logs and the Trash in your home folder.",
        "App caches": "Caches kept by built-in macOS apps like Maps, Help and Siri.",
        "Browsers": "Cached pages and data from your web browsers.",
        "Developer tools": "Package and build caches from tools like npm, pip and Homebrew.",
        "Application Support": "Logs and caches that apps stash in Application Support.",
    ]
}
