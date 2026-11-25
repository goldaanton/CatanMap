import SwiftUI
import Charts

struct DiceScreen: View {
    @Environment(AppModel.self) private var model
    @State private var showPlayers = false

    var body: some View {
        let dice = model.dice
        @Bindable var bindableDice = dice
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    turnHeader(dice)

                    HStack(spacing: 24) {
                        DieView(value: dice.d1)
                        DieView(value: dice.d2)
                    }
                    .frame(maxWidth: 300)
                    .rotationEffect(.degrees(dice.isRolling ? Double((dice.d1 * 37 + dice.d2 * 11) % 30 - 15) : 0))
                    .animation(.easeOut(duration: 0.08), value: dice.d1)
                    .onTapGesture { roll() }

                    resultView(dice)

                    Button(action: roll) {
                        Label("Кинути кубики", systemImage: "dice.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: 320)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(dice.isRolling)
                    .keyboardShortcut(.space, modifiers: [])

                    Picker("Режим", selection: $bindableDice.mode) {
                        ForEach(DiceMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    if dice.mode == .deck {
                        Text("Як «Catan Event Cards»: усі 36 комбінацій випадають рівно за статистикою. Колоду перемішано, коли лишається 5 карт. Залишилось: \(dice.deckRemaining)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 420)
                    }

                    GroupBox {
                        BoardView(board: model.board,
                                  highlightNumber: dice.lastSum,
                                  robberHex: model.robberHex)
                            .frame(height: 300)
                    } label: {
                        Label(dice.lastSum.map { $0 == 7 ? "Розбійник виходить на поле" : "Що приносить \($0)" } ?? "Поле",
                              systemImage: "map")
                    }

                    GroupBox {
                        histogram(dice)
                    } label: {
                        Label("Статистика кидків: \(dice.rolls.count)", systemImage: "chart.bar.xaxis")
                    }
                }
                .padding()
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Кубики")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showPlayers = true
                    } label: {
                        Label("Гравці", systemImage: "person.3")
                    }
                    Button(role: .destructive) {
                        dice.reset()
                    } label: {
                        Label("Скинути статистику", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .sheet(isPresented: $showPlayers) { PlayersView() }
            .rollHaptic(trigger: dice.rollTick)
        }
    }

    private func roll() {
        Task { await model.dice.roll() }
    }

    @ViewBuilder
    private func turnHeader(_ dice: DiceModel) -> some View {
        if !dice.players.isEmpty {
            let next = dice.players[dice.currentPlayer % dice.players.count]
            HStack(spacing: 16) {
                if let last = dice.lastRoller {
                    HStack(spacing: 6) {
                        Circle().fill(last.color).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                        Text("Кинув: \(last.name)").foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(next.color).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                    Text("Хід: \(next.name)").fontWeight(.semibold)
                }
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private func resultView(_ dice: DiceModel) -> some View {
        if let sum = dice.lastSum, !dice.isRolling {
            VStack(spacing: 6) {
                Text("\(sum)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(sum == 7 ? Color.primary : (sum.isRed ? Color.red : Color.primary))
                    .contentTransition(.numericText())
                if sum == 7 {
                    Text("🥷 Розбійник! У кого більше 7 карт — скидає половину.")
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                } else {
                    Text(production(for: sum))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            Text(dice.isRolling ? "…" : "Торкніться кубиків або натисніть пробіл")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(height: 90)
        }
    }

    private func production(for sum: Int) -> String {
        let hexes = model.board.hexes.filter { $0.number == sum }
        let active = hexes.filter { $0.id != model.robberHex }
        var parts: [String] = []
        for r in Resource.producing {
            let c = active.filter { $0.resource == r }.count
            if c > 0 { parts.append("\(r.emoji) \(r.cardName)\(c > 1 ? " ×\(c)" : "")") }
        }
        var text = parts.isEmpty ? "Нічого не виробляється" : "Виробляють: " + parts.joined(separator: " · ")
        if hexes.count != active.count { text += "\n🚫 Один гекс заблоковано розбійником" }
        return text
    }

    @ViewBuilder
    private func histogram(_ dice: DiceModel) -> some View {
        let total = dice.rolls.count
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(Array(2...12), id: \.self) { n in
                    BarMark(x: .value("Сума", String(n)), y: .value("Кидки", Double(dice.count(of: n))))
                        .foregroundStyle(n == 7 ? Color.gray : (n.isRed ? Color.red : Color.accentColor))
                        .cornerRadius(4)
                    if total > 0 {
                        PointMark(x: .value("Сума", String(n)),
                                  y: .value("Кидки", Double(total) * Double(n.pips) / 36))
                            .foregroundStyle(Color.orange)
                            .symbolSize(40)
                    }
                }
            }
            .frame(height: 200)
            HStack(spacing: 16) {
                Label("Факт", systemImage: "square.fill").foregroundStyle(Color.accentColor)
                Label("Очікувано за теорією", systemImage: "circle.fill").foregroundStyle(.orange)
            }
            .font(.caption)
            if total > 0 {
                let sevens = dice.count(of: 7)
                let hot = (2...12).max { dice.count(of: $0) < dice.count(of: $1) } ?? 7
                Text("Сімок: \(sevens) (очікувано \(String(format: "%.1f", Double(total) / 6))) · Найчастіше: \(hot)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Останні: " + dice.rolls.suffix(15).map(String.init).joined(separator: " "))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DieView: View {
    let value: Int

    private static let pipLayout: [Int: [Int]] = [
        1: [4], 2: [0, 8], 3: [0, 4, 8], 4: [0, 2, 6, 8], 5: [0, 2, 4, 6, 8], 6: [0, 2, 3, 5, 6, 8],
    ]

    var body: some View {
        Canvas { ctx, size in
            let s = Double(min(size.width, size.height))
            let rect = CGRect(x: 0, y: 0, width: s, height: s).insetBy(dx: 2, dy: 2)
            let shape = Path(roundedRect: rect, cornerRadius: s * 0.18)
            ctx.fill(shape, with: .linearGradient(Gradient(colors: [.white, Color(white: 0.88)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: s, y: s)))
            ctx.stroke(shape, with: .color(.black.opacity(0.2)), lineWidth: 1.5)
            let r = s * 0.085
            for i in Self.pipLayout[value] ?? [] {
                let x = s * (0.25 + 0.25 * Double(i % 3))
                let y = s * (0.25 + 0.25 * Double(i / 3))
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(value == 1 ? .red : Color(white: 0.1)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        .accessibilityLabel("Кубик: \(value)")
    }
}

struct PlayersView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var dice = model.dice
        NavigationStack {
            Form {
                Section {
                    Stepper("Гравців: \(dice.players.count)",
                            onIncrement: { dice.setPlayerCount(dice.players.count + 1) },
                            onDecrement: { dice.setPlayerCount(dice.players.count - 1) })
                    ForEach($dice.players) { $player in
                        HStack {
                            Circle().fill(player.color).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.secondary, lineWidth: 0.5))
                            TextField("Ім’я", text: $player.name)
                        }
                    }
                    .onMove { dice.players.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text("Порядок у списку — порядок ходів. Після кожного кидка хід переходить до наступного.")
                }

                Section {
                    Button {
                        dice.shufflePlayers()
                    } label: {
                        Label("Випадковий порядок ходів", systemImage: "shuffle")
                    }
                    if let first = dice.players.first {
                        Text("Першим ходить: \(first.name)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Гравці")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 460)
        #endif
    }
}

extension View {
    @ViewBuilder
    func rollHaptic(trigger: Int) -> some View {
        #if os(iOS)
        sensoryFeedback(.impact(weight: .heavy), trigger: trigger)
        #else
        self
        #endif
    }
}
