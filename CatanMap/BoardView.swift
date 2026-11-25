import SwiftUI

struct BoardFit {
    let scale: Double
    let offX: Double
    let offY: Double

    init(layout: BoardLayout, size: CGSize, pad: Double = 1.9) {
        let xs = layout.centers.map(\.x)
        let ys = layout.centers.map(\.y)
        let minX = (xs.min() ?? 0) - pad, maxX = (xs.max() ?? 0) + pad
        let minY = (ys.min() ?? 0) - pad, maxY = (ys.max() ?? 0) + pad
        let w = Double(size.width), h = Double(size.height)
        scale = max(0, min(w / (maxX - minX), h / (maxY - minY)))
        offX = w / 2 - (minX + maxX) / 2 * scale
        offY = h / 2 - (minY + maxY) / 2 * scale
    }

    func pt(_ p: Pt) -> CGPoint { CGPoint(x: p.x * scale + offX, y: p.y * scale + offY) }
    func unit(_ p: CGPoint) -> Pt { Pt(x: (Double(p.x) - offX) / scale, y: (Double(p.y) - offY) / scale) }
}

func hexPath(_ c: CGPoint, _ r: Double) -> Path {
    var p = Path()
    for k in 0..<6 {
        let a = (Double(k) * 60 - 90) * .pi / 180
        let pt = CGPoint(x: Double(c.x) + cos(a) * r, y: Double(c.y) + sin(a) * r)
        if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

private func circle(_ c: CGPoint, _ r: Double) -> Path {
    Path(ellipseIn: CGRect(x: Double(c.x) - r, y: Double(c.y) - r, width: r * 2, height: r * 2))
}

struct BoardView: View {
    let board: Board
    var overlay: MapOverlay = .none
    var analysis: BoardAnalysis? = nil
    var highlightNumber: Int? = nil
    var robberHex: Int? = nil
    var selectedHex: Int? = nil
    var onTapHex: ((Int) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let layout = board.layout
            let fit = BoardFit(layout: layout, size: geo.size)
            let info: BoardAnalysis? = overlay == .none ? nil : (analysis ?? BoardAnalysis(board: board))
            Canvas { ctx, _ in
                draw(&ctx, layout: layout, fit: fit, info: info)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                guard let onTapHex, fit.scale > 0 else { return }
                let u = fit.unit(location)
                let best = layout.centers.indices.min { a, b in
                    hypot(layout.centers[a].x - u.x, layout.centers[a].y - u.y)
                        < hypot(layout.centers[b].x - u.x, layout.centers[b].y - u.y)
                }
                if let best, hypot(layout.centers[best].x - u.x, layout.centers[best].y - u.y) < 0.95 {
                    onTapHex(best)
                }
            }
        }
        .accessibilityLabel("Карта Катану, код \(board.code)")
    }

    // MARK: - Drawing

    private func draw(_ ctx: inout GraphicsContext, layout L: BoardLayout, fit: BoardFit, info: BoardAnalysis?) {
        let s = fit.scale
        guard s > 2 else { return }

        // Sea
        let deep = Color(red: 0.12, green: 0.36, blue: 0.62)
        let shallow = Color(red: 0.22, green: 0.52, blue: 0.78)
        for c in L.centers { ctx.fill(hexPath(fit.pt(c), s * 1.9), with: .color(deep)) }
        for c in L.centers { ctx.fill(hexPath(fit.pt(c), s * 1.3), with: .color(shallow)) }

        // Harbors
        let wood = Color(red: 0.55, green: 0.38, blue: 0.22)
        for h in board.harbors {
            let a = L.vertices[h.vertexA], b = L.vertices[h.vertexB], c = L.centers[h.hex]
            let m = Pt(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            var dx = m.x - c.x, dy = m.y - c.y
            let len = max(0.001, hypot(dx, dy))
            dx /= len
            dy /= len
            let hp = fit.pt(Pt(x: m.x + dx * 0.68, y: m.y + dy * 0.68))
            var piers = Path()
            piers.move(to: fit.pt(a)); piers.addLine(to: hp)
            piers.move(to: fit.pt(b)); piers.addLine(to: hp)
            ctx.stroke(piers, with: .color(wood), style: StrokeStyle(lineWidth: s * 0.1, lineCap: .round))

            let ring = circle(hp, s * 0.33)
            ctx.fill(ring, with: .color(Color(red: 0.99, green: 0.96, blue: 0.88)))
            ctx.stroke(ring, with: .color(h.resource?.color ?? wood), lineWidth: s * 0.06)
            if let r = h.resource {
                ctx.draw(Text(r.emoji).font(.system(size: s * 0.24)),
                         at: CGPoint(x: hp.x, y: hp.y - s * 0.09))
                ctx.draw(Text("2:1").font(.system(size: s * 0.15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.15)),
                         at: CGPoint(x: hp.x, y: hp.y + s * 0.15))
            } else {
                ctx.draw(Text("3:1").font(.system(size: s * 0.2, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(white: 0.15)), at: hp)
            }
        }

        // Tiles
        let border = Color(red: 0.97, green: 0.91, blue: 0.74)
        for hex in board.hexes {
            let c = fit.pt(L.centers[hex.id])
            let path = hexPath(c, s * 0.97)
            ctx.fill(path, with: .linearGradient(Gradient(colors: [hex.resource.lightColor, hex.resource.color]),
                                                 startPoint: CGPoint(x: c.x - s * 0.5, y: c.y - s),
                                                 endPoint: CGPoint(x: c.x + s * 0.5, y: c.y + s)))
            ctx.stroke(path, with: .color(border), lineWidth: s * 0.08)

            let hasNumber = hex.number != nil
            ctx.draw(Text(hex.resource.emoji).font(.system(size: s * (hasNumber ? 0.42 : 0.75))),
                     at: CGPoint(x: c.x, y: c.y - (hasNumber ? s * 0.5 : 0)))
            if let n = hex.number {
                drawToken(&ctx, number: n, at: CGPoint(x: c.x, y: c.y + s * 0.14), s: s)
            }

            if let hn = highlightNumber {
                let lit = hex.number == hn && hex.id != robberHex
                if lit {
                    ctx.stroke(hexPath(c, s * 0.9), with: .color(.yellow), lineWidth: s * 0.12)
                } else {
                    ctx.fill(path, with: .color(.black.opacity(0.5)))
                }
            }
            if selectedHex == hex.id {
                ctx.stroke(hexPath(c, s * 0.88), with: .color(.white),
                           style: StrokeStyle(lineWidth: s * 0.1, dash: [s * 0.18, s * 0.1]))
            }
        }

        // Robber
        if let rh = robberHex, rh < L.centers.count {
            let c = fit.pt(L.centers[rh])
            let x = c.x - s * 0.55, y = c.y + s * 0.12
            let body = Path(roundedRect: CGRect(x: x - s * 0.14, y: y - s * 0.08, width: s * 0.28, height: s * 0.34),
                            cornerRadius: s * 0.1)
            let head = circle(CGPoint(x: x, y: y - s * 0.17), s * 0.11)
            for p in [body, head] {
                ctx.fill(p, with: .color(Color(white: 0.12)))
                ctx.stroke(p, with: .color(.white.opacity(0.85)), lineWidth: s * 0.025)
            }
        }

        // Overlays
        guard let info else { return }
        switch overlay {
        case .none:
            break
        case .heat:
            let maxP = Double(max(1, info.vertexPips.max() ?? 1))
            for (v, p) in info.vertexPips.enumerated() where p > 0 {
                let t = Double(p) / maxP
                let pt = fit.pt(L.vertices[v])
                let dot = circle(pt, s * 0.17)
                ctx.fill(dot, with: .color(Color(hue: 0.62 * (1 - t), saturation: 0.85, brightness: 0.97)))
                ctx.stroke(dot, with: .color(.white), lineWidth: s * 0.025)
                ctx.draw(Text("\(p)").font(.system(size: s * 0.15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.1)), at: pt)
            }
        case .spots:
            for spot in info.spots {
                let pt = fit.pt(L.vertices[spot.id])
                let dot = circle(pt, s * 0.24)
                ctx.fill(dot, with: .color(Color(red: 1.0, green: 0.8, blue: 0.1)))
                ctx.stroke(dot, with: .color(Color(white: 0.15)), lineWidth: s * 0.04)
                ctx.draw(Text("\(spot.rank)").font(.system(size: s * 0.24, weight: .black, design: .rounded))
                    .foregroundStyle(Color(white: 0.1)), at: pt)
            }
        }
    }

    private func drawToken(_ ctx: inout GraphicsContext, number n: Int, at p: CGPoint, s: Double) {
        let disc = circle(p, s * 0.37)
        ctx.fill(disc, with: .color(Color(red: 0.99, green: 0.95, blue: 0.85)))
        ctx.stroke(disc, with: .color(.black.opacity(0.25)), lineWidth: s * 0.025)
        let ink: Color = n.isRed ? Color(red: 0.82, green: 0.1, blue: 0.1) : Color(white: 0.12)
        ctx.draw(Text("\(n)").font(.system(size: s * (n.isRed ? 0.36 : 0.3), weight: .heavy, design: .rounded))
            .foregroundStyle(ink), at: CGPoint(x: p.x, y: p.y - s * 0.05))
        let k = n.pips
        let step = s * 0.075
        let startX = Double(p.x) - step * Double(k - 1) / 2
        for i in 0..<k {
            ctx.fill(circle(CGPoint(x: startX + step * Double(i), y: Double(p.y) + s * 0.21), s * 0.026),
                     with: .color(ink))
        }
    }
}
