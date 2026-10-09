import Foundation

/// One line of `mo status --watch`. Every field optional so a schema change can't crash the app.
struct StatusSnapshot: Decodable {
    var uptime: String?
    var procs: Int?
    var hardware: Hardware?
    var healthScore: Int?
    var healthScoreMsg: String?
    var cpu: CPU?
    var memory: Memory?
    var disks: [Disk]?
    var network: [Net]?
    var batteries: [Battery]?
    var thermal: Thermal?
    var topProcesses: [Proc_]?

    struct Hardware: Decodable { var model: String?; var cpuModel: String?; var totalRam: String?; var osVersion: String? }
    struct CPU: Decodable { var usage: Double?; var perCore: [Double]?; var load1: Double?; var pCoreCount: Int?; var eCoreCount: Int? }
    struct Memory: Decodable { var used: Double?; var total: Double?; var usedPercent: Double?; var swapUsed: Double?; var swapTotal: Double? }
    struct Disk: Decodable { var mount: String?; var used: Double?; var total: Double?; var usedPercent: Double?; var external: Bool? }
    struct Net: Decodable { var name: String?; var rxRateMbs: Double?; var txRateMbs: Double?; var ip: String? }
    struct Battery: Decodable { var percent: Double?; var status: String?; var timeLeft: String?; var health: String?; var cycleCount: Int? }
    struct Thermal: Decodable { var cpuTemp: Double?; var fanSpeed: Double? }
    struct Proc_: Decodable, Identifiable {
        var pid: Int; var name: String?; var cpu: Double?; var memoryBytes: Double?
        var id: Int { pid }
    }
}
