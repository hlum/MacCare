import Foundation
import Observation

struct OptStep: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var results: [String]
}

@Observable
final class OptimizeStore {
    enum Phase { case idle, scanning, ready, running, done }
    var phase: Phase = .idle
    var steps: [OptStep] = []
    var note: String?
    var current = 0                 // index of the step mo is on while running
    var failed: String?

    static func parse(_ text: String) -> (steps: [OptStep], note: String?) {
        var out: [OptStep] = [], note: String?
        for raw in text.split(separator: "\n") {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("➤ ") { out.append(OptStep(name: String(t.dropFirst(2)), results: [])) }
            else if t.hasPrefix("→ "), !out.isEmpty { out[out.count - 1].results.append(String(t.dropFirst(2))) }
            else if t.hasPrefix("◎ Memory pressure") { note = String(t.dropFirst(2)) }
        }
        return (out.filter { !$0.results.isEmpty }, note)
    }

    func scan() {
        guard phase != .scanning, phase != .running else { return }
        phase = .scanning
        Task { @MainActor in
            let r = await Mo.run(["optimize", "--dry-run"])
            let p = Self.parse(r.out); steps = p.steps; note = p.note
            phase = .ready
        }
    }

    func run() {
        guard phase == .ready else { return }
        phase = .running; current = 0; failed = nil
        Task { @MainActor in
            Activity.shared.begin()
            // No terminal means no admin prompt. This makes mo skip the steps that need sudo instead of waiting on a password.
            let run = Proc.lines(Mo.path, ["optimize"], extraEnv: ["MOLE_TEST_NO_AUTH": "1"])
            var seen = 0
            for await line in run.stream {
                let t = Proc.stripANSI(line).trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("➤ ") { seen += 1; current = min(seen - 1, max(steps.count - 1, 0)) }
                if t.lowercased().contains("failed") && failed == nil { failed = t }
            }
            let code = await run.wait()
            Activity.shared.end()
            if code != 0 && failed == nil { failed = "mo optimize exited with code \(code)." }
            current = steps.count
            phase = .done
        }
    }
}
