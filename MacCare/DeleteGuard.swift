import Foundation

/// The one gate every Xcode-page deletion goes through. Ported from cleanX's `guard`.
/// Allowed: strict children of ~/Library/Developer, ~/Library/Caches, ~/Library/Logs, and top-level /Applications/Xcode*.app.
/// Refused: path tricks (..), the roots themselves, CoreDevice (a mirror of a connected iPhone), the active Xcode,
/// and anything that sits on a different volume than the home folder.
enum DeleteGuard {
    static func allowed(_ rawPath: String,
                        home: String = NSHomeDirectory(),
                        activeXcode: String? = nil,
                        checkVolume: Bool = true) -> Bool {
        guard rawPath.hasPrefix("/"), !rawPath.contains("\0") else { return false }
        // Reject traversal outright instead of "fixing" it.
        if rawPath.split(separator: "/").contains("..") { return false }
        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path

        if let active = activeXcode, path == active || path.hasPrefix(active + "/") { return false }

        // Whole Xcode apps: /Applications/Xcode<anything>.app, directly in /Applications.
        if path.range(of: #"^/Applications/Xcode[^/]*\.app$"#, options: .regularExpression) != nil {
            return !checkVolume || sameVolume(path, home)
        }

        let roots = ["\(home)/Library/Developer/", "\(home)/Library/Caches/", "\(home)/Library/Logs/"]
        guard roots.contains(where: { path.hasPrefix($0) && path.count > $0.count }) else { return false }
        if path == "\(home)/Library/Developer/CoreDevice" || path.hasPrefix("\(home)/Library/Developer/CoreDevice/") { return false }
        return !checkVolume || sameVolume(path, home)
    }

    /// True when the nearest existing ancestor of `path` is on the same device as `home`.
    static func sameVolume(_ path: String, _ home: String) -> Bool {
        var probe = path
        var st = stat(), hs = stat()
        while !FileManager.default.fileExists(atPath: probe) && probe != "/" { probe = (probe as NSString).deletingLastPathComponent }
        guard stat(probe, &st) == 0, stat(home, &hs) == 0 else { return false }
        return st.st_dev == hs.st_dev
    }

    enum Outcome { case removed, refused, failed(String) }

    /// Remove one path (a directory tree or a file). Symlinks are removed as links, never followed.
    @discardableResult
    static func remove(_ path: String, activeXcode: String? = nil, trash: Bool = false) -> Outcome {
        guard allowed(path, activeXcode: activeXcode) else { return .refused }
        guard FileManager.default.fileExists(atPath: path) || (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil else { return .removed }
        do {
            if trash { try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil) }
            else { try FileManager.default.removeItem(atPath: path) }
            return .removed
        } catch { return .failed(error.localizedDescription) }
    }

    /// Empty a directory but keep the directory itself.
    static func empty(_ dir: String, activeXcode: String? = nil) -> [Outcome] {
        guard allowed(dir + "/x", activeXcode: activeXcode),
              let kids = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        return kids.map { remove(dir + "/" + $0, activeXcode: activeXcode) }
    }
}
