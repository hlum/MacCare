import Foundation
import Observation

@Observable
final class StatusStore {
    var snap = StatusSnapshot()
    var cpuHist: [Double] = []
    var memHist: [Double] = []
    var rxHist: [Double] = []
    var txHist: [Double] = []
    var live = false

    private var task: Task<Void, Never>?
    private var stopper: (() -> Void)?

    var startDisk: StatusSnapshot.Disk? { snap.disks?.first { $0.external != true } ?? snap.disks?.first }
    var rx: Double { snap.network?.map { $0.rxRateMbs ?? 0 }.reduce(0, +) ?? 0 }   // MB/s
    var tx: Double { snap.network?.map { $0.txRateMbs ?? 0 }.reduce(0, +) ?? 0 }

    func start() {
        guard task == nil, Mo.installed else { return }
        let run = Proc.lines(Mo.path, ["status", "--watch", "--interval", "1s"])
        let stream = run.stream
        stopper = run.stop
        task = Task { @MainActor [weak self] in
            for await line in stream {
                guard let self, let data = line.data(using: .utf8),
                      let s = try? Mo.decoder.decode(StatusSnapshot.self, from: data) else { continue }
                self.apply(s)
            }
            self?.live = false
        }
    }

    func stop() { stopper?(); task?.cancel(); task = nil; live = false }

    @MainActor private func apply(_ s: StatusSnapshot) {
        snap = s
        live = true
        func push(_ a: inout [Double], _ v: Double) { a.append(v); if a.count > 60 { a.removeFirst(a.count - 60) } }
        push(&cpuHist, s.cpu?.usage ?? 0)
        push(&memHist, s.memory?.usedPercent ?? 0)
        push(&rxHist, rx)
        push(&txHist, tx)
    }
}
