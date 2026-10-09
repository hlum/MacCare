import Foundation

/// Thin wrapper over the `mo` CLI. Everything MacCare does to your disk goes through here or through `DeleteGuard`.
enum Mo {
    /// Homebrew on Apple Silicon, then Intel.
    static var path: String {
        ["/opt/homebrew/bin/mo", "/usr/local/bin/mo"].first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/opt/homebrew/bin/mo"
    }
    static var installed: Bool { FileManager.default.isExecutableFile(atPath: path) }

    static func run(_ args: [String], stdin: String? = nil) async -> ProcResult {
        var r = await Proc.run(path, args, stdin: stdin)
        r = ProcResult(out: Proc.stripANSI(r.out), err: Proc.stripANSI(r.err), code: r.code)
        return r
    }

    static func version() async -> String {
        let r = await run(["--version"])
        return r.out.split(separator: "\n").first.map(String.init) ?? "unknown"
    }

    static func json<T: Decodable>(_ type: T.Type, _ args: [String]) async -> T? {
        let r = await run(args)
        return try? decoder.decode(T.self, from: Data(r.out.utf8))
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
