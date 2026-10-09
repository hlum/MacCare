import SwiftUI

struct StatusView: View {
    @Environment(StatusStore.self) private var store
    @State private var dialValue: Double = 0

    var body: some View {
        let s = store.snap
        Scroller {
            VStack(alignment: .leading, spacing: 28) {
                header(s)
                HStack(alignment: .top, spacing: 14) {
                    healthCard(s).frame(width: 380)
                    VStack(spacing: 14) {
                        cpuCard(s)
                        HStack(spacing: 14) { memoryCard(s); diskCard }
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    networkCard.frame(maxWidth: .infinity)
                    batteryCard(s).frame(width: 220)
                    thermalCard(s).frame(width: 220)
                }
                processCard(s)
            }
            .padding(.horizontal, 40).padding(.vertical, 28)
            .frame(maxWidth: 1320)
            .frame(maxWidth: .infinity)
        }
        .onAppear { withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 1.6).delay(0.2)) { dialValue = Double(s.healthScore ?? 0) / 100 } }
        .onChange(of: s.healthScore) { _, new in withAnimation(T.spring) { dialValue = Double(new ?? 0) / 100 } }
    }

    func header(_ s: StatusSnapshot) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(store.live ? T.safe : T.faint).frame(width: 7, height: 7)
                    Eyebrow(text: store.live ? "Live · 1 s" : "Connecting")
                }
                Text("\(s.hardware?.model ?? "Mac")")
                    .font(.system(size: 44, weight: .medium)).tracking(-2).foregroundStyle(T.bone)
                + Text(" · \(s.hardware?.cpuModel?.replacingOccurrences(of: "Apple ", with: "") ?? "") · \(s.hardware?.totalRam ?? "")")
                    .font(.system(size: 44, weight: .medium)).tracking(-2).foregroundStyle(T.faint)
            }
            Spacer()
            HStack(spacing: 20) {
                label("UP \(s.uptime ?? "—")"); label("\(s.procs ?? 0) PROCESSES")
                label("LOAD \(String(format: "%.2f", s.cpu?.load1 ?? 0))"); label(s.hardware?.osVersion ?? "")
            }
        }
    }

    func label(_ t: String) -> some View { Text(t.uppercased()).font(T.mono(11)).foregroundStyle(T.dim) }

    func healthCard(_ s: StatusSnapshot) -> some View {
        Bezel(padding: 24) {
            VStack(spacing: 6) {
                HStack { Eyebrow(text: "Health"); Spacer() }
                ZStack {
                    TickDial(value: dialValue).frame(width: 290, height: 290)
                    VStack(spacing: 6) {
                        Text("\(s.healthScore ?? 0)").font(.system(size: 108, weight: .medium)).tracking(-6)
                            .monospacedDigit().foregroundStyle(T.bone).contentTransition(.numericText())
                        Text((s.healthScoreMsg ?? "").uppercased()).font(T.mono(11)).tracking(2.4).foregroundStyle(T.safe)
                    }
                }
                Text("Memory is the busiest thing right now. Everything else is well within range.")
                    .font(T.sans(14)).foregroundStyle(T.mute).multilineTextAlignment(.center).frame(maxWidth: 260)
            }
        }
    }

    func cpuCard(_ s: StatusSnapshot) -> some View {
        Bezel(padding: 24) {
            HStack(alignment: .bottom, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "CPU")
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int((s.cpu?.usage ?? 0).rounded()))").font(.system(size: 64, weight: .medium)).tracking(-4).monospacedDigit()
                        Text("%").font(.system(size: 24)).foregroundStyle(T.mute)
                    }
                    Text("\(s.cpu?.pCoreCount ?? 0) PERFORMANCE · \(s.cpu?.eCoreCount ?? 0) EFFICIENCY").font(T.mono(11)).foregroundStyle(T.dim)
                }
                .frame(width: 210, alignment: .leading)
                let cores = s.cpu?.perCore ?? []
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(cores.enumerated()), id: \.offset) { i, v in
                        VStack(spacing: 6) {
                            GeometryReader { g in
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06))
                                    RoundedRectangle(cornerRadius: 5).fill(i < (s.cpu?.pCoreCount ?? 4) ? T.accent : T.bone)
                                        .frame(height: max(4, g.size.height * min(v, 100) / 100))
                                }
                            }
                            .frame(height: 96)
                            Text("\(i < (s.cpu?.pCoreCount ?? 4) ? "P" : "E")\(i < (s.cpu?.pCoreCount ?? 4) ? i + 1 : i - (s.cpu?.pCoreCount ?? 4) + 1)")
                                .font(T.mono(10)).foregroundStyle(T.faint)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(T.spring, value: cores)
            }
        }
    }

    func memoryCard(_ s: StatusSnapshot) -> some View {
        let pct = s.memory?.usedPercent ?? 0
        return Bezel(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "Memory"); Spacer(); if pct > 75 { Text("WARM").font(T.mono(11)).foregroundStyle(T.caution) } }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(pct.rounded()))").font(.system(size: 54, weight: .medium)).tracking(-3).monospacedDigit()
                    Text("%").font(.system(size: 22)).foregroundStyle(T.mute)
                }
                TickMeter(value: pct / 100, on: pct > 75 ? T.caution : T.bone, count: 36).frame(height: 24)
                Text("\(Fmt.bytes(s.memory?.used ?? 0)) of \(Fmt.bytes(s.memory?.total ?? 0)) · SWAP \(Fmt.bytes(s.memory?.swapUsed ?? 0))")
                    .font(T.mono(11)).foregroundStyle(T.dim)
            }
        }
    }

    var diskCard: some View {
        let d = store.startDisk
        let free = (d?.total ?? 0) - (d?.used ?? 0)
        let (n, u) = Fmt.bigBytes(free)
        return Bezel(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "Disk free")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(n).font(.system(size: 54, weight: .medium)).tracking(-3).monospacedDigit()
                    Text(u).font(.system(size: 22)).foregroundStyle(T.mute)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.1))
                        Capsule().fill(T.bone).frame(width: g.size.width * min((d?.usedPercent ?? 0) / 100, 1))
                    }
                }.frame(height: 4)
                Text("\(Fmt.bytes(d?.used ?? 0)) of \(Fmt.bytes(d?.total ?? 0)) used").font(T.mono(11)).foregroundStyle(T.dim)
            }
        }
    }

    var networkCard: some View {
        Bezel(padding: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Eyebrow(text: "Network"); Spacer()
                    Text("↓ \(rate(store.rx))").font(T.mono(13)).foregroundStyle(T.bone)
                    Text("↑ \(rate(store.tx))").font(T.mono(13)).foregroundStyle(T.mute)
                }
                Sparkline(values: store.rxHist, color: T.accent, fill: true).frame(height: 96)
                HStack { Text("−60 S"); Spacer(); Text("NOW") }.font(T.mono(10)).foregroundStyle(T.faint)
            }
        }
    }

    func rate(_ mbs: Double) -> String { mbs >= 1 ? String(format: "%.1f MB/s", mbs) : String(format: "%.0f KB/s", mbs * 1024) }

    func batteryCard(_ s: StatusSnapshot) -> some View {
        let b = s.batteries?.first
        return Bezel(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "Battery"); Spacer(); Image(systemName: "battery.75percent").foregroundStyle(T.faint) }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(b == nil ? "—" : "\(Int(b?.percent ?? 0))").font(.system(size: 54, weight: .medium)).tracking(-3).monospacedDigit()
                    if b != nil { Text("%").font(.system(size: 22)).foregroundStyle(T.mute) }
                }
                Text(b == nil ? "NO BATTERY" : "\((b?.status ?? "").uppercased()) · \(b?.cycleCount ?? 0) CYCLES").font(T.mono(11)).foregroundStyle(T.dim)
            }
        }
    }

    func thermalCard(_ s: StatusSnapshot) -> some View {
        Bezel(padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "Thermal"); Spacer(); Image(systemName: "thermometer.medium").foregroundStyle(T.faint) }
                Text("Nominal").font(.system(size: 36, weight: .medium)).tracking(-2).padding(.top, 8)
                Text((s.thermal?.cpuTemp ?? 0) > 0 ? "\(Int(s.thermal?.cpuTemp ?? 0))° CPU" : "NO THROTTLING").font(T.mono(11)).foregroundStyle(T.dim)
            }
        }
    }

    func processCard(_ s: StatusSnapshot) -> some View {
        let procs = Array((s.topProcesses ?? []).sorted { ($0.cpu ?? 0) > ($1.cpu ?? 0) }.prefix(6))
        return Bezel(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    label("Process").frame(maxWidth: .infinity, alignment: .leading)
                    label("CPU ▾").frame(width: 280, alignment: .leading)
                    label("Memory").frame(width: 90, alignment: .trailing)
                }.padding(.horizontal, 26).padding(.vertical, 14)
                ForEach(procs) { p in
                    Divider().overlay(T.hair)
                    HStack {
                        Text(p.name ?? "—").font(T.sans(14, .medium)).foregroundStyle(T.bone).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 12) {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule().fill(T.accent).frame(width: g.size.width * min((p.cpu ?? 0) / 100, 1))
                                }
                            }.frame(height: 3)
                            Text(String(format: "%.1f%%", p.cpu ?? 0)).font(T.mono(12)).foregroundStyle(T.bone).frame(width: 52, alignment: .trailing)
                        }.frame(width: 280)
                        Text(Fmt.bytes(p.memoryBytes ?? 0)).font(T.mono(12)).foregroundStyle(T.mute).frame(width: 90, alignment: .trailing)
                    }.padding(.horizontal, 26).padding(.vertical, 12)
                }
            }
        }
    }
}

/// 270° tick dial.
struct TickDial: View, Animatable {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View {
        Canvas { ctx, size in
            let n = 61, c = CGPoint(x: size.width / 2, y: size.height / 2), r = size.width / 2
            let lit = Int((Double(n - 1) * value).rounded())
            for i in 0..<n {
                let a = (-225.0 + Double(i) * 270.0 / Double(n - 1)) * .pi / 180
                let head = i == lit, on = i <= lit
                let len: CGFloat = head ? 26 : 18
                var p = Path()
                p.move(to: CGPoint(x: c.x + cos(a) * (r - len), y: c.y + sin(a) * (r - len)))
                p.addLine(to: CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
                ctx.stroke(p, with: .color(head ? T.accent : (on ? T.bone : T.bone.opacity(0.12))), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }
}

struct TickMeter: View {
    var value: Double, on: Color, count: Int
    var body: some View {
        GeometryReader { g in
            HStack(spacing: 3) {
                ForEach(0..<count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Double(i) < value * Double(count) ? on : T.bone.opacity(0.12))
                }
            }
        }
    }
}

struct Sparkline: View {
    var values: [Double], color: Color, fill: Bool
    var body: some View {
        GeometryReader { g in
            let vs = values.count > 1 ? values : [0, 0]
            let mx = max(vs.max() ?? 1, 0.05)
            let pts = vs.enumerated().map { CGPoint(x: g.size.width * CGFloat($0.offset) / CGFloat(vs.count - 1),
                                                    y: g.size.height * (1 - CGFloat($0.element / mx) * 0.9) - 2) }
            ZStack {
                if fill {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: g.size.height)); pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: g.size.width, y: g.size.height)); p.closeSubpath()
                    }.fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                }
                Path { p in p.move(to: pts[0]); pts.dropFirst().forEach { p.addLine(to: $0) } }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
    }
}
