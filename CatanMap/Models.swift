import SwiftUI

// MARK: - Base types

struct Pt: Codable, Hashable {
    var x: Double
    var y: Double
}

extension Int {
    /// Number of pips on the token (roll probability out of 36).
    var pips: Int { Swift.max(0, 6 - abs(7 - self)) }
    var isRed: Bool { self == 6 || self == 8 }
    var isRare: Bool { self == 2 || self == 3 || self == 11 || self == 12 }
}

enum Resource: String, Codable, CaseIterable, Identifiable {
    case wood, brick, sheep, wheat, ore, desert

    var id: String { rawValue }

    static let producing: [Resource] = [.wood, .brick, .sheep, .wheat, .ore]

    var tileName: String {
        switch self {
        case .wood: return "Ліс"
        case .brick: return "Пагорби"
        case .sheep: return "Пасовище"
        case .wheat: return "Поле"
        case .ore: return "Гори"
        case .desert: return "Пустеля"
        }
    }

    var cardName: String {
        switch self {
        case .wood: return "Деревина"
        case .brick: return "Глина"
        case .sheep: return "Вовна"
        case .wheat: return "Зерно"
        case .ore: return "Руда"
        case .desert: return "—"
        }
    }

    var emoji: String {
        switch self {
        case .wood: return "🌲"
        case .brick: return "🧱"
        case .sheep: return "🐑"
        case .wheat: return "🌾"
        case .ore: return "⛰️"
        case .desert: return "🏜️"
        }
    }

    var color: Color {
        switch self {
        case .wood: return Color(red: 0.13, green: 0.42, blue: 0.20)
        case .brick: return Color(red: 0.72, green: 0.32, blue: 0.18)
        case .sheep: return Color(red: 0.45, green: 0.72, blue: 0.28)
        case .wheat: return Color(red: 0.90, green: 0.70, blue: 0.18)
        case .ore: return Color(red: 0.45, green: 0.48, blue: 0.56)
        case .desert: return Color(red: 0.82, green: 0.72, blue: 0.50)
        }
    }

    var lightColor: Color {
        switch self {
        case .wood: return Color(red: 0.25, green: 0.58, blue: 0.30)
        case .brick: return Color(red: 0.86, green: 0.48, blue: 0.30)
        case .sheep: return Color(red: 0.62, green: 0.86, blue: 0.42)
        case .wheat: return Color(red: 0.98, green: 0.85, blue: 0.40)
        case .ore: return Color(red: 0.64, green: 0.67, blue: 0.74)
        case .desert: return Color(red: 0.95, green: 0.88, blue: 0.68)
        }
    }
}

enum BoardSize: String, Codable, CaseIterable, Identifiable {
    case standard, extended

    var id: String { rawValue }
    var title: String { self == .standard ? "3–4 гравці" : "5–6 гравців" }
    var rows: [Int] { self == .standard ? [3, 4, 5, 4, 3] : [3, 4, 5, 6, 5, 4, 3] }
    var codeChar: String { self == .standard ? "S" : "E" }

    var resourceBag: [Resource] {
        let counts: [(Resource, Int)] = self == .standard
            ? [(.wood, 4), (.sheep, 4), (.wheat, 4), (.brick, 3), (.ore, 3), (.desert, 1)]
            : [(.wood, 6), (.sheep, 6), (.wheat, 6), (.brick, 5), (.ore, 5), (.desert, 2)]
        return counts.flatMap { pair in Array(repeating: pair.0, count: pair.1) }
    }

    var numberBag: [Int] {
        if self == .standard { return [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12] }
        return [2, 2] + [3, 4, 5, 6, 8, 9, 10, 11].flatMap { n in Array(repeating: n, count: 3) } + [12, 12]
    }

    /// nil = generic 3:1 harbor.
    var harborBag: [Resource?] {
        self == .standard
            ? [nil, nil, nil, nil, .wood, .brick, .sheep, .wheat, .ore]
            : [nil, nil, nil, nil, nil, .wood, .brick, .sheep, .sheep, .wheat, .ore]
    }
}

enum NumberMode: String, Codable, CaseIterable, Identifiable {
    case balanced, spiral
    var id: String { rawValue }
    var title: String { self == .balanced ? "Випадково з правилами" : "Класична спіраль (A–R)" }
}

struct GeneratorSettings: Codable, Equatable {
    var size: BoardSize = .standard
    var numberMode: NumberMode = .balanced
    var noAdjacentRed = true
    var noAdjacentSameNumber = true
    var spreadRareNumbers = true
    var noAdjacentSameResource = true
    var desertInCenter = false
    var balanceResources = true
    /// 0 = no limit.
    var maxIntersectionPips = 12

    var pipCapOn: Bool {
        get { maxIntersectionPips > 0 }
        set { maxIntersectionPips = newValue ? 12 : 0 }
    }

    static let tournament = GeneratorSettings()
    static let classic = GeneratorSettings(numberMode: .spiral, noAdjacentRed: false, noAdjacentSameNumber: false,
                                           spreadRareNumbers: false, noAdjacentSameResource: false,
                                           desertInCenter: false, balanceResources: false, maxIntersectionPips: 0)
    static let chaos = GeneratorSettings(numberMode: .balanced, noAdjacentRed: false, noAdjacentSameNumber: false,
                                         spreadRareNumbers: false, noAdjacentSameResource: false,
                                         desertInCenter: false, balanceResources: false, maxIntersectionPips: 0)
}

struct Hex: Codable, Equatable, Identifiable {
    var id: Int
    var resource: Resource
    var number: Int?
}

struct Harbor: Codable, Equatable, Identifiable {
    var id: Int
    /// nil — 3:1
    var resource: Resource?
    var vertexA: Int
    var vertexB: Int
    var hex: Int

    var ratio: String { resource == nil ? "3:1" : "2:1" }
    var title: String { resource.map { "\($0.emoji) 2:1" } ?? "3:1" }
}

struct Board: Codable, Equatable, Identifiable {
    var id: UUID
    var code: String
    var settings: GeneratorSettings
    var hexes: [Hex]
    var harbors: [Harbor]
    var created: Date
    var isFavorite: Bool
    var isEdited: Bool

    var layout: BoardLayout { BoardLayout.of(settings.size) }
    var displayCode: String { isEdited ? "\(code) ✎" : code }
}

enum MapOverlay: String, CaseIterable, Identifiable {
    case none, heat, spots
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Карта"
        case .heat: return "Теплова"
        case .spots: return "Топ-місця"
        }
    }
}

enum TileEditMode: String, CaseIterable, Identifiable {
    case off, swapTiles, swapNumbers, robber
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Перегляд"
        case .swapTiles: return "Міняти плитки"
        case .swapNumbers: return "Міняти числа"
        case .robber: return "Ставити розбійника"
        }
    }
    var icon: String {
        switch self {
        case .off: return "eye"
        case .swapTiles: return "arrow.left.arrow.right"
        case .swapNumbers: return "number"
        case .robber: return "figure.stand"
        }
    }
}

// MARK: - Board code

/// Format: S3F12-K9X2QA  (size, hex flags, pip limit, seed in base36)
enum MapCode {
    static func make(settings s: GeneratorSettings, seed: UInt64) -> String {
        var flags = 0
        if s.noAdjacentRed { flags |= 1 }
        if s.noAdjacentSameNumber { flags |= 2 }
        if s.spreadRareNumbers { flags |= 4 }
        if s.noAdjacentSameResource { flags |= 8 }
        if s.desertInCenter { flags |= 16 }
        if s.balanceResources { flags |= 32 }
        if s.numberMode == .spiral { flags |= 64 }
        let f = String(flags, radix: 16, uppercase: true)
        let fPadded = f.count < 2 ? "0" + f : f
        let pips = s.maxIntersectionPips < 10 ? "0\(s.maxIntersectionPips)" : "\(s.maxIntersectionPips)"
        return "\(s.size.codeChar)\(fPadded)\(pips)-\(String(seed, radix: 36, uppercase: true))"
    }

    static func parse(_ raw: String) -> (GeneratorSettings, UInt64)? {
        let code = raw.uppercased().replacingOccurrences(of: " ", with: "")
        let parts = code.split(separator: "-")
        guard parts.count == 2, parts[0].count == 5 else { return nil }
        let head = Array(parts[0])
        var s = GeneratorSettings()
        switch head[0] {
        case "S": s.size = .standard
        case "E": s.size = .extended
        default: return nil
        }
        guard let flags = Int(String(head[1...2]), radix: 16),
              let pips = Int(String(head[3...4])),
              let seed = UInt64(String(parts[1]), radix: 36) else { return nil }
        s.noAdjacentRed = flags & 1 != 0
        s.noAdjacentSameNumber = flags & 2 != 0
        s.spreadRareNumbers = flags & 4 != 0
        s.noAdjacentSameResource = flags & 8 != 0
        s.desertInCenter = flags & 16 != 0
        s.balanceResources = flags & 32 != 0
        s.numberMode = flags & 64 != 0 ? .spiral : .balanced
        s.maxIntersectionPips = pips
        return (s, seed)
    }
}

// MARK: - Persistence

enum Persistence {
    static func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
