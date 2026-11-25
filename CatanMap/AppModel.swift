import SwiftUI
import Observation

enum AppTab: Hashable { case map, dice, history }

@MainActor
@Observable
final class AppModel {
    var settings: GeneratorSettings {
        didSet { Persistence.save(settings, key: "settings") }
    }
    var board: Board {
        didSet { analysis = BoardAnalysis(board: board) }
    }
    private(set) var analysis: BoardAnalysis
    var history: [Board] {
        didSet { Persistence.save(history, key: "history") }
    }

    var tab: AppTab = .map
    var overlay: MapOverlay = .none
    var editMode: TileEditMode = .off {
        didSet { selectedHex = nil }
    }
    var selectedHex: Int?
    var robberHex: Int?
    let dice = DiceModel()

    init() {
        let s = Persistence.load(GeneratorSettings.self, key: "settings") ?? GeneratorSettings()
        let h = Persistence.load([Board].self, key: "history") ?? []
        let b = h.first ?? BoardGenerator.generate(settings: s, seed: UInt64(UInt32.random(in: 0...UInt32.max)))
        settings = s
        history = h.isEmpty ? [b] : h
        board = b
        analysis = BoardAnalysis(board: b)
        robberHex = b.hexes.first { $0.resource == .desert }?.id
    }

    // MARK: - Actions

    func generate() {
        let seed = UInt64(UInt32.random(in: 0...UInt32.max))
        board = BoardGenerator.generate(settings: settings, seed: seed)
        didCreateBoard()
    }

    func loadBeginner() {
        board = BoardGenerator.beginner()
        didCreateBoard()
    }

    func load(_ b: Board) {
        board = b
        robberHex = b.hexes.first { $0.resource == .desert }?.id
        selectedHex = nil
        tab = .map
    }

    @discardableResult
    func load(code raw: String) -> Bool {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if code == "BEGINNER" || code == "СТАРТ" {
            loadBeginner()
            return true
        }
        guard let parsed = MapCode.parse(code) else { return false }
        let (s, seed) = parsed
        settings = s
        board = BoardGenerator.generate(settings: s, seed: seed)
        didCreateBoard()
        return true
    }

    func toggleFavorite() {
        board.isFavorite.toggle()
        syncHistory()
    }

    func toggleFavorite(_ b: Board) {
        guard let i = history.firstIndex(where: { $0.id == b.id }) else { return }
        history[i].isFavorite.toggle()
        if board.id == b.id { board.isFavorite = history[i].isFavorite }
    }

    func delete(_ b: Board) {
        history.removeAll { $0.id == b.id }
    }

    func clearHistory() {
        history.removeAll { !$0.isFavorite && $0.id != board.id }
    }

    func tapHex(_ id: Int) {
        switch editMode {
        case .off:
            return
        case .robber:
            robberHex = id
        case .swapTiles, .swapNumbers:
            guard let sel = selectedHex else {
                selectedHex = id
                return
            }
            if sel == id {
                selectedHex = nil
                return
            }
            var b = board
            if editMode == .swapTiles {
                let tmp = b.hexes[sel]
                b.hexes[sel].resource = b.hexes[id].resource
                b.hexes[sel].number = b.hexes[id].number
                b.hexes[id].resource = tmp.resource
                b.hexes[id].number = tmp.number
                if robberHex == sel { robberHex = id } else if robberHex == id { robberHex = sel }
            } else {
                guard b.hexes[sel].number != nil, b.hexes[id].number != nil else {
                    selectedHex = id
                    return
                }
                let tmp = b.hexes[sel].number
                b.hexes[sel].number = b.hexes[id].number
                b.hexes[id].number = tmp
            }
            b.isEdited = true
            board = b
            selectedHex = nil
            syncHistory()
        }
    }

    // MARK: - Private

    private func didCreateBoard() {
        robberHex = board.hexes.first { $0.resource == .desert }?.id
        selectedHex = nil
        editMode = .off
        history.removeAll { $0.id == board.id }
        history.insert(board, at: 0)
        var kept: [Board] = []
        var regular = 0
        for b in history {
            if b.isFavorite { kept.append(b) } else if regular < 50 { kept.append(b); regular += 1 }
        }
        if kept.count != history.count { history = kept }
    }

    private func syncHistory() {
        if let i = history.firstIndex(where: { $0.id == board.id }) {
            history[i] = board
        } else {
            history.insert(board, at: 0)
        }
    }
}

// MARK: - Dice

struct Player: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var colorIndex: Int

    static let palette: [Color] = [
        Color(red: 0.85, green: 0.15, blue: 0.15), Color(red: 0.15, green: 0.35, blue: 0.85),
        Color(white: 0.92), Color(red: 0.98, green: 0.55, blue: 0.10),
        Color(red: 0.15, green: 0.6, blue: 0.25), Color(red: 0.45, green: 0.28, blue: 0.15),
    ]
    static let defaultNames = ["Червоний", "Синій", "Білий", "Помаранчевий", "Зелений", "Коричневий"]
    var color: Color { Player.palette[colorIndex % Player.palette.count] }
}

enum DiceMode: String, CaseIterable, Identifiable {
    case random, deck
    var id: String { rawValue }
    var title: String { self == .random ? "Звичайні кубики" : "Колода 36 карт" }
}

struct DicePair: Equatable {
    let a: Int
    let b: Int
}

@MainActor
@Observable
final class DiceModel {
    var mode: DiceMode = .random
    var d1 = 3
    var d2 = 4
    var rolls: [Int] = []
    var isRolling = false
    var rollTick = 0
    var currentPlayer = 0
    var lastRoller: Player?
    private(set) var deck: [DicePair] = []
    var players: [Player] {
        didSet { Persistence.save(players, key: "players") }
    }

    init() {
        players = Persistence.load([Player].self, key: "players")
            ?? (0..<4).map { Player(name: Player.defaultNames[$0], colorIndex: $0) }
    }

    var lastSum: Int? { rolls.last }
    var deckRemaining: Int { deck.count }

    func count(of sum: Int) -> Int { rolls.filter { $0 == sum }.count }

    func roll() async {
        guard !isRolling else { return }
        isRolling = true
        for _ in 0..<8 {
            d1 = Int.random(in: 1...6)
            d2 = Int.random(in: 1...6)
            try? await Task.sleep(for: .milliseconds(55))
        }
        let pair = nextPair()
        d1 = pair.a
        d2 = pair.b
        rolls.append(pair.a + pair.b)
        if !players.isEmpty {
            lastRoller = players[currentPlayer % players.count]
            currentPlayer = (currentPlayer + 1) % players.count
        }
        rollTick += 1
        isRolling = false
    }

    func reset() {
        rolls = []
        deck = []
        lastRoller = nil
        currentPlayer = 0
    }

    func shufflePlayers() {
        players.shuffle()
        currentPlayer = 0
        lastRoller = nil
    }

    func setPlayerCount(_ n: Int) {
        let n = max(2, min(6, n))
        if players.count > n {
            players = Array(players.prefix(n))
        } else {
            while players.count < n {
                let used = Set(players.map(\.colorIndex))
                let idx = (0..<6).first { !used.contains($0) } ?? players.count
                players.append(Player(name: Player.defaultNames[idx], colorIndex: idx))
            }
        }
        currentPlayer = currentPlayer % players.count
    }

    private func nextPair() -> DicePair {
        if mode == .deck {
            if deck.count <= 5 {
                deck = (1...6).flatMap { a in (1...6).map { b in DicePair(a: a, b: b) } }.shuffled()
            }
            return deck.removeLast()
        }
        return DicePair(a: Int.random(in: 1...6), b: Int.random(in: 1...6))
    }
}
