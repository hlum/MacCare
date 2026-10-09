import Foundation

/// Counts destructive runs in flight so quitting can warn instead of killing `mo` halfway through deleting.
final class Activity {
    static let shared = Activity()
    private let lock = NSLock()
    private var n = 0
    var busy: Bool { lock.lock(); defer { lock.unlock() }; return n > 0 }
    func begin() { lock.lock(); n += 1; lock.unlock() }
    func end() { lock.lock(); n = max(0, n - 1); lock.unlock() }
}
