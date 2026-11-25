import Foundation

struct CoastEdge {
    let a: Int
    let b: Int
    let hex: Int
}

/// Board geometry: hex centers, vertices (intersections), adjacency, coastline.
/// Unit = hex radius (center to corner); hexes are pointy-top.
final class BoardLayout {
    static let sqrt3 = 3.0.squareRoot()
    static let standard = BoardLayout(size: .standard)
    static let extended = BoardLayout(size: .extended)
    static func of(_ size: BoardSize) -> BoardLayout { size == .standard ? standard : extended }

    let size: BoardSize
    let centers: [Pt]
    let neighbors: [[Int]]
    let vertices: [Pt]
    let hexVertices: [[Int]]
    let vertexHexes: [[Int]]
    let vertexNeighbors: [[Int]]
    let coast: [CoastEdge]
    let depth: [Int]
    let cornerHexes: [Int]

    static func corner(of c: Pt, _ k: Int, radius: Double = 1) -> Pt {
        let a = (Double(k) * 60 - 90) * .pi / 180
        return Pt(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius)
    }

    private struct Key: Hashable { let x: Int; let y: Int }
    private struct EdgeKey: Hashable { let a: Int; let b: Int }

    private init(size: BoardSize) {
        self.size = size
        let rows = size.rows
        let mid = Double(rows.count - 1) / 2

        var cs: [Pt] = []
        for (ri, len) in rows.enumerated() {
            for i in 0..<len {
                cs.append(Pt(x: (Double(i) - Double(len - 1) / 2) * Self.sqrt3,
                             y: (Double(ri) - mid) * 1.5))
            }
        }
        let n = cs.count

        var nb = [[Int]](repeating: [], count: n)
        for i in 0..<n {
            for j in 0..<n where i != j {
                if hypot(cs[i].x - cs[j].x, cs[i].y - cs[j].y) < Self.sqrt3 * 1.1 {
                    nb[i].append(j)
                }
            }
        }

        var keyIndex: [Key: Int] = [:]
        var verts: [Pt] = []
        var hv = [[Int]](repeating: [], count: n)
        var vh: [[Int]] = []
        for h in 0..<n {
            for k in 0..<6 {
                let p = Self.corner(of: cs[h], k)
                let key = Key(x: Int((p.x * 100).rounded()), y: Int((p.y * 100).rounded()))
                let idx: Int
                if let existing = keyIndex[key] {
                    idx = existing
                } else {
                    idx = verts.count
                    keyIndex[key] = idx
                    verts.append(p)
                    vh.append([])
                }
                hv[h].append(idx)
                vh[idx].append(h)
            }
        }

        var edgeHexes: [EdgeKey: [Int]] = [:]
        for h in 0..<n {
            for k in 0..<6 {
                let a = hv[h][k], b = hv[h][(k + 1) % 6]
                edgeHexes[EdgeKey(a: min(a, b), b: max(a, b)), default: []].append(h)
            }
        }
        var vn = [Set<Int>](repeating: [], count: verts.count)
        var coastEdges: [CoastEdge] = []
        for (e, hexes) in edgeHexes {
            vn[e.a].insert(e.b)
            vn[e.b].insert(e.a)
            if hexes.count == 1 { coastEdges.append(CoastEdge(a: e.a, b: e.b, hex: hexes[0])) }
        }
        coastEdges.sort { lhs, rhs in
            let m1 = Pt(x: (verts[lhs.a].x + verts[lhs.b].x) / 2, y: (verts[lhs.a].y + verts[lhs.b].y) / 2)
            let m2 = Pt(x: (verts[rhs.a].x + verts[rhs.b].x) / 2, y: (verts[rhs.a].y + verts[rhs.b].y) / 2)
            return atan2(m1.y, m1.x) < atan2(m2.y, m2.x)
        }

        var d = [Int](repeating: -1, count: n)
        for i in 0..<n where nb[i].count < 6 { d[i] = 0 }
        var level = 0
        while d.contains(-1) {
            var changed = false
            for i in 0..<n where d[i] == -1 && nb[i].contains(where: { d[$0] == level }) {
                d[i] = level + 1
                changed = true
            }
            level += 1
            if !changed { break }
        }

        centers = cs
        neighbors = nb
        vertices = verts
        hexVertices = hv
        vertexHexes = vh
        vertexNeighbors = vn.map { Array($0).sorted() }
        coast = coastEdges
        depth = d
        cornerHexes = (0..<n).filter { d[$0] == 0 && nb[$0].count == 3 }
    }

    func angle(of hex: Int) -> Double { atan2(centers[hex].y, centers[hex].x) }
}
