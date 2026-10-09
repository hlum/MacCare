import Foundation

struct ProcResult {
    let out: String
    let err: String
    let code: Int32
    var ok: Bool { code == 0 }
}

/// Subprocess helpers. A GUI app has no shell PATH, so everything gets an explicit one.
enum Proc {
    static let env: [String: String] = [
        "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
        "HOME": NSHomeDirectory(),
        "NO_COLOR": "1",
        "TERM": "dumb",
        "LANG": "en_US.UTF-8",
    ]

    static func stripANSI(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r", with: "")
    }

    /// Run to completion. Pipes are drained before waiting, so large output can't deadlock.
    static func run(_ exe: String, _ args: [String], stdin: String? = nil) async -> ProcResult {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: exe)
                p.arguments = args
                p.environment = env
                let outPipe = Pipe(), errPipe = Pipe()
                p.standardOutput = outPipe
                p.standardError = errPipe
                let inPipe = Pipe()
                p.standardInput = stdin == nil ? FileHandle.nullDevice : inPipe
                Terminator.shared.register(p)
                do { try p.run() } catch {
                    cont.resume(returning: ProcResult(out: "", err: "\(error)", code: -1)); return
                }
                if let stdin {
                    inPipe.fileHandleForWriting.write(Data(stdin.utf8))
                    try? inPipe.fileHandleForWriting.close()
                }
                var errData = Data()
                let errDone = DispatchSemaphore(value: 0)
                DispatchQueue.global().async { errData = errPipe.fileHandleForReading.readDataToEndOfFile(); errDone.signal() }
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                errDone.wait()
                p.waitUntilExit()
                cont.resume(returning: ProcResult(
                    out: String(decoding: outData, as: UTF8.self),
                    err: String(decoding: errData, as: UTF8.self),
                    code: p.terminationStatus))
            }
        }
    }

    /// Run and deliver output line by line as it arrives. Await `run.wait()` after the stream ends for the exit code.
    static func lines(_ exe: String, _ args: [String], stdin: String? = nil, extraEnv: [String: String] = [:]) -> LineRun {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        p.environment = env.merging(extraEnv) { $1 }
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = outPipe
        let inPipe = Pipe()
        p.standardInput = stdin == nil ? FileHandle.nullDevice : inPipe     // closed stdin => not a TTY => mo runs non-interactively
        Terminator.shared.register(p)
        let stream = AsyncStream<String> { cont in
            var buffer = Data()
            outPipe.fileHandleForReading.readabilityHandler = { h in
                let chunk = h.availableData
                if chunk.isEmpty {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    if !buffer.isEmpty { cont.yield(String(decoding: buffer, as: UTF8.self)) }
                    cont.finish(); return
                }
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<nl]
                    buffer.removeSubrange(buffer.startIndex...nl)
                    cont.yield(String(decoding: line, as: UTF8.self))
                }
            }
            cont.onTermination = { _ in if p.isRunning { p.terminate() } }
        }
        let started: Bool
        do { try p.run(); started = true } catch { started = false }
        if started, let stdin {
            inPipe.fileHandleForWriting.write(Data(stdin.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
        return LineRun(stream: started ? stream : AsyncStream { $0.finish() }, proc: p, started: started)
    }
}

final class LineRun {
    let stream: AsyncStream<String>
    private let proc: Process
    private let started: Bool
    init(stream: AsyncStream<String>, proc: Process, started: Bool) { self.stream = stream; self.proc = proc; self.started = started }
    func stop() { if proc.isRunning { proc.terminate() } }
    /// Exit status, or -1 if the process never started.
    func wait() async -> Int32 {
        guard started else { return -1 }
        return await withCheckedContinuation { c in DispatchQueue.global().async { self.proc.waitUntilExit(); c.resume(returning: self.proc.terminationStatus) } }
    }
}

/// Makes sure long-running children (mo status --watch) die with the app.
final class Terminator {
    static let shared = Terminator()
    private var procs: [Process] = []
    private let lock = NSLock()
    func register(_ p: Process) { lock.lock(); procs.removeAll { !$0.isRunning && $0.processIdentifier != 0 }; procs.append(p); lock.unlock() }
    func killAll() { lock.lock(); procs.forEach { if $0.isRunning { $0.terminate() } }; lock.unlock() }
}
