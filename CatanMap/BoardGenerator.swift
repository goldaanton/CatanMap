import Foundation

/// Deterministic generator: same seed + settings → same board.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x1234_5678_9ABC_DEF0 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum BoardGenerator {
    static let spiralSequence = [5, 2, 6, 3, 8, 10, 9, 12, 11, 4, 8, 10, 9, 4, 5, 6, 3, 11]

    static func generate(settings: GeneratorSettings, seed: UInt64) -> Board {
        let layout = BoardLayout.of(settings.size)
        var rng = SplitMix64(seed: seed)
        let n = layout.centers.count

        // 1. Resources
        var bestRes = settings.size.resourceBag
        var bestResPenalty = Int.max
        for _ in 0..<3000 {
            var res = settings.size.resourceBag.shuffled(using: &rng)
            if settings.desertInCenter { res = moveDesertsToCenter(res, layout: layout) }
            let p = settings.noAdjacentSameResource ? resourcePenalty(res, layout: layout) : 0
            if p < bestResPenalty {
                bestResPenalty = p
                bestRes = res
            }
            if p == 0 { break }
        }

        // 2. Numbers
        let producing = (0..<n).filter { bestRes[$0] != .desert }
        var bestNums = [Int?](repeating: nil, count: n)
        if settings.numberMode == .spiral && settings.size == .standard {
            bestNums = spiralNumbers(resources: bestRes, layout: layout, rng: &rng)
        } else {
            var bestP = Double.infinity
            for _ in 0..<5000 {
                let tokens = settings.size.numberBag.shuffled(using: &rng)
                var nums = [Int?](repeating: nil, count: n)
                for (i, h) in producing.enumerated() { nums[h] = tokens[i] }
                let p = numberPenalty(nums, resources: bestRes, layout: layout, settings: settings)
                if p < bestP {
                    bestP = p
                    bestNums = nums
                }
                if p == 0 { break }
            }
        }

        // 3. Harbors
        let harbors = makeHarbors(layout: layout, size: settings.size, rng: &rng)

        let hexes = (0..<n).map { Hex(id: $0, resource: bestRes[$0], number: bestNums[$0]) }
        return Board(id: UUID(), code: MapCode.make(settings: settings, seed: seed), settings: settings,
                     hexes: hexes, harbors: harbors, created: Date(), isFavorite: false, isEdited: false)
    }

    /// Starter layout from the rulebook (for beginners). Harbors are random.
    static func beginner() -> Board {
        let res: [Resource] = [.ore, .sheep, .wood,
                               .wheat, .brick, .sheep, .brick,
                               .wheat, .wood, .desert, .wood, .ore,
                               .wood, .ore, .wheat, .sheep,
                               .brick, .wheat, .sheep]
        let nums: [Int?] = [10, 2, 9,
                            12, 6, 4, 10,
                            9, 11, nil, 3, 8,
                            8, 3, 4, 5,
                            5, 6, 11]
        var rng = SplitMix64(seed: 2024)
        let layout = BoardLayout.standard
        var settings = GeneratorSettings.classic
        settings.numberMode = .spiral
        let hexes = (0..<res.count).map { Hex(id: $0, resource: res[$0], number: nums[$0]) }
        return Board(id: UUID(), code: "BEGINNER", settings: settings, hexes: hexes,
                     harbors: makeHarbors(layout: layout, size: .standard, rng: &rng),
                     created: Date(), isFavorite: false, isEdited: false)
    }

    // MARK: - Helpers

    private static func moveDesertsToCenter(_ input: [Resource], layout: BoardLayout) -> [Resource] {
        var res = input
        let order = res.indices.sorted { a, b in
            let da = hypot(layout.centers[a].x, layout.centers[a].y)
            let db = hypot(layout.centers[b].x, layout.centers[b].y)
            return da == db ? a < b : da < db
        }
        let k = res.filter { $0 == .desert }.count
        let targets = Array(order.prefix(k))
        for t in targets where res[t] != .desert {
            if let d = res.indices.first(where: { res[$0] == .desert && !targets.contains($0) }) {
                res.swapAt(t, d)
            }
        }
        return res
    }

    static func resourcePenalty(_ res: [Resource], layout: BoardLayout) -> Int {
        var p = 0
        for i in res.indices {
            for j in layout.neighbors[i] where j > i && res[i] == res[j] { p += 1 }
        }
        return p
    }

    static func numberPenalty(_ nums: [Int?], resources: [Resource], layout: BoardLayout,
                              settings s: GeneratorSettings) -> Double {
        var p = 0.0
        for i in nums.indices {
            guard let a = nums[i] else { continue }
            for j in layout.neighbors[i] where j > i {
                guard let b = nums[j] else { continue }
                if s.noAdjacentRed && a.isRed && b.isRed { p += 10 }
                if s.noAdjacentSameNumber && a == b { p += 5 }
                if s.spreadRareNumbers && a.isRare && b.isRare { p += 1 }
            }
        }
        if s.maxIntersectionPips > 0 {
            for hexes in layout.vertexHexes {
                let sum = hexes.reduce(0) { acc, h in acc + (nums[h]?.pips ?? 0) }
                if sum > s.maxIntersectionPips { p += Double(sum - s.maxIntersectionPips) * 3 }
            }
        }
        if s.balanceResources {
            var avgs: [Double] = []
            for r in Resource.producing {
                let idx = resources.indices.filter { resources[$0] == r }
                guard !idx.isEmpty else { continue }
                let total = idx.reduce(0) { acc, h in acc + (nums[h]?.pips ?? 0) }
                avgs.append(Double(total) / Double(idx.count))
            }
            let spread = (avgs.max() ?? 0) - (avgs.min() ?? 0)
            p += max(0, spread - 0.9) * 4
        }
        return p
    }

    private static func spiralNumbers(resources: [Resource], layout: BoardLayout,
                                      rng: inout SplitMix64) -> [Int?] {
        let n = layout.centers.count
        let start = layout.cornerHexes.randomElement(using: &rng) ?? 0
        let startAngle = layout.angle(of: start)
        let clockwise = Bool.random(using: &rng)
        func rel(_ h: Int) -> Double {
            if layout.centers[h].x == 0 && layout.centers[h].y == 0 { return 0 }
            var r = (layout.angle(of: h) - startAngle) * (clockwise ? 1 : -1)
            while r < -1e-9 { r += 2 * .pi }
            if r >= 2 * .pi - 1e-9 { r = 0 }
            return r
        }
        let order = (0..<n).sorted { a, b in
            layout.depth[a] != layout.depth[b] ? layout.depth[a] < layout.depth[b] : rel(a) < rel(b)
        }
        var nums = [Int?](repeating: nil, count: n)
        var k = 0
        for h in order where resources[h] != .desert && k < spiralSequence.count {
            nums[h] = spiralSequence[k]
            k += 1
        }
        return nums
    }

    private static func makeHarbors(layout: BoardLayout, size: BoardSize, rng: inout SplitMix64) -> [Harbor] {
        let kinds = size.harborBag.shuffled(using: &rng)
        let e = layout.coast.count
        let k = kinds.count
        let offset = Int.random(in: 0..<e, using: &rng)
        return kinds.enumerated().map { i, kind in
            let edge = layout.coast[(offset + (i * e) / k) % e]
            return Harbor(id: i, resource: kind, vertexA: edge.a, vertexB: edge.b, hex: edge.hex)
        }
    }
}
