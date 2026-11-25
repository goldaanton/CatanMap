import Foundation

struct ResourceStat: Identifiable {
    let resource: Resource
    let tiles: Int
    let pips: Int
    let numbers: [Int]
    var id: Resource { resource }
    var average: Double { tiles == 0 ? 0 : Double(pips) / Double(tiles) }
}

struct SpotInfo: Identifiable {
    let id: Int          // vertex index
    let rank: Int
    let pips: Int
    let score: Double
    let hexes: [Hex]
    let harbor: Harbor?
}

/// Board analysis: intersection value, best spots, balance.
struct BoardAnalysis {
    let vertexPips: [Int]
    let vertexScore: [Double]
    let spots: [SpotInfo]
    let resourceStats: [ResourceStat]
    let fairness: Int
    let issues: [String]
    let positives: [String]

    init(board: Board) {
        let layout = board.layout
        let hexes = board.hexes

        var harborAt: [Int: Harbor] = [:]
        for h in board.harbors {
            harborAt[h.vertexA] = h
            harborAt[h.vertexB] = h
        }

        var vp: [Int] = []
        var vs: [Double] = []
        for v in layout.vertices.indices {
            let around = layout.vertexHexes[v].map { hexes[$0] }
            let pips = around.reduce(0) { acc, h in acc + (h.number?.pips ?? 0) }
            let distinct = Set(around.filter { $0.number != nil }.map(\.resource)).count
            var score = Double(pips) + Double(max(0, distinct - 1)) * 0.7
            if let harbor = harborAt[v] {
                if let r = harbor.resource {
                    score += around.contains(where: { $0.resource == r }) ? 1.2 : 0.4
                } else {
                    score += 0.6
                }
            }
            vp.append(pips)
            vs.append(score)
        }
        vertexPips = vp
        vertexScore = vs

        let order = vs.indices.sorted { a, b in vs[a] == vs[b] ? a < b : vs[a] > vs[b] }
        var chosen: [Int] = []
        var blocked = Set<Int>()
        for v in order where !blocked.contains(v) {
            chosen.append(v)
            blocked.insert(v)
            blocked.formUnion(layout.vertexNeighbors[v])
            if chosen.count == 6 { break }
        }
        spots = chosen.enumerated().map { rank, v in
            SpotInfo(id: v, rank: rank + 1, pips: vp[v], score: vs[v],
                     hexes: layout.vertexHexes[v].map { hexes[$0] }.filter { $0.number != nil },
                     harbor: harborAt[v])
        }

        resourceStats = Resource.producing.map { r in
            let tiles = hexes.filter { $0.resource == r }
            return ResourceStat(resource: r, tiles: tiles.count,
                                pips: tiles.reduce(0) { acc, h in acc + (h.number?.pips ?? 0) },
                                numbers: tiles.compactMap(\.number).sorted())
        }

        var redPairs = 0, samePairs = 0, resPairs = 0
        for i in hexes.indices {
            for j in layout.neighbors[i] where j > i {
                let a = hexes[i], b = hexes[j]
                if a.resource == b.resource { resPairs += 1 }
                if let x = a.number, let y = b.number {
                    if x.isRed && y.isRed { redPairs += 1 }
                    if x == y { samePairs += 1 }
                }
            }
        }
        let avgs = resourceStats.map(\.average)
        let spread = (avgs.max() ?? 0) - (avgs.min() ?? 0)
        let maxV = vp.max() ?? 0

        var score = 100.0
        score -= Double(redPairs) * 12
        score -= Double(samePairs) * 5
        score -= Double(resPairs) * 4
        score -= max(0, spread - 0.6) * 15
        score -= Double(max(0, maxV - 11)) * 5
        fairness = Int(max(0, min(100, score)).rounded())

        var bad: [String] = []
        var good: [String] = []
        if redPairs > 0 { bad.append("Червоні 6/8 поруч: \(redPairs)") } else { good.append("6 і 8 не торкаються") }
        if samePairs > 0 { bad.append("Однакові числа поруч: \(samePairs)") }
        if resPairs > 0 { bad.append("Однакові ресурси поруч: \(resPairs)") } else { good.append("Ресурси рівномірно розкидані") }
        if spread > 1.0 {
            let rich = resourceStats.max { $0.average < $1.average }!
            let poor = resourceStats.min { $0.average < $1.average }!
            bad.append("\(rich.resource.cardName) значно щедріша, ніж \(poor.resource.cardName.lowercased())")
        } else {
            good.append("Ресурси приблизно однаково ймовірні")
        }
        if maxV > 11 { bad.append("Є «гаряче» перехрестя на \(maxV) крапок") }
        issues = bad
        positives = good
    }

    static func fairnessLabel(_ value: Int) -> String {
        switch value {
        case 90...: return "Ідеально збалансована"
        case 75..<90: return "Добрий баланс"
        case 55..<75: return "Є перекоси"
        default: return "Дикий хаос"
        }
    }
}
