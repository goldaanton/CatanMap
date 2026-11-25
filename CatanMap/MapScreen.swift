import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

func copyToClipboard(_ s: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = s
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(s, forType: .string)
    #endif
}

struct MapScreen: View {
    @Environment(AppModel.self) private var model
    @State private var showSettings = false
    @State private var showCodeEntry = false
    @State private var shareImage: Image?
    @State private var copied = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let wide = geo.size.width > 720 && geo.size.width > geo.size.height * 1.1
                if wide {
                    HStack(spacing: 0) {
                        boardArea
                            .padding()
                        Divider()
                        ScrollView { StatsPanel().padding() }
                            .frame(width: 360)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            boardArea
                                .frame(height: max(380, min(geo.size.width * 1.15, geo.size.height * 0.85)))
                            StatsPanel()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Карта Катану")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showCodeEntry) { CodeEntryView() }
            .onChange(of: model.board, initial: true) { _, newBoard in
                shareImage = renderShareImage(board: newBoard)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.toggleFavorite()
            } label: {
                Label("В обране", systemImage: model.board.isFavorite ? "star.fill" : "star")
            }
            if let shareImage {
                ShareLink(item: shareImage,
                          subject: Text("Карта Катану"),
                          message: Text("Код карти: \(model.board.code)"),
                          preview: SharePreview("Карта \(model.board.code)", image: shareImage)) {
                    Label("Поділитися", systemImage: "square.and.arrow.up")
                }
            }
            Menu {
                Button("Ввести код карти…", systemImage: "keyboard") { showCodeEntry = true }
                Button("Стартова карта з правил", systemImage: "book") { model.loadBeginner() }
                Button("Скопіювати код", systemImage: "doc.on.doc") { copyToClipboard(model.board.code) }
            } label: {
                Label("Більше", systemImage: "ellipsis.circle")
            }
            Button {
                showSettings = true
            } label: {
                Label("Налаштування", systemImage: "slider.horizontal.3")
            }
        }
    }

    private var boardArea: some View {
        @Bindable var model = model
        return VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.board.settings.size.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        copyToClipboard(model.board.code)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(1.5))
                            copied = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(model.board.displayCode)
                                .font(.system(.headline, design: .monospaced))
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Скопіювати код — за ним можна відтворити цю карту")
                }
                Spacer()
                FairnessBadge(value: model.analysis.fairness)
            }

            BoardView(board: model.board,
                      overlay: model.overlay,
                      analysis: model.analysis,
                      robberHex: model.robberHex,
                      selectedHex: model.selectedHex,
                      onTapHex: { model.tapHex($0) })
                .id(model.board.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .bottom) {
                    if model.editMode != .off {
                        Text(editHint)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(10)
                    }
                }

            HStack {
                Picker("Шар", selection: $model.overlay) {
                    ForEach(MapOverlay.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Menu {
                    Picker("Режим", selection: $model.editMode) {
                        ForEach(TileEditMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.icon).tag(mode)
                        }
                    }
                } label: {
                    Image(systemName: model.editMode == .off ? "hand.tap" : model.editMode.icon)
                        .frame(minWidth: 28)
                }
                .fixedSize()
                .help("Ручне редагування карти")
            }

            Button {
                withAnimation(.spring(duration: 0.4)) { model.generate() }
            } label: {
                Label("Нова карта", systemImage: "shuffle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("g", modifiers: .command)
        }
    }

    private var editHint: String {
        switch model.editMode {
        case .off: return ""
        case .robber: return "Торкніться гекса, щоб поставити розбійника"
        case .swapTiles: return model.selectedHex == nil ? "Оберіть першу плитку" : "Тепер другу — поміняю місцями"
        case .swapNumbers: return model.selectedHex == nil ? "Оберіть перше число" : "Тепер друге — поміняю числа"
        }
    }

    @MainActor
    private func renderShareImage(board: Board) -> Image? {
        let renderer = ImageRenderer(content: ShareCard(board: board).environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return nil }
        return Image(decorative: cg, scale: 2)
    }
}

struct ShareCard: View {
    let board: Board
    var body: some View {
        let a = BoardAnalysis(board: board)
        VStack(spacing: 12) {
            Text("Карта Катану · \(board.settings.size.title)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            BoardView(board: board, analysis: a)
                .frame(width: 720, height: 660)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            HStack {
                Text("Код: \(board.code)").font(.system(size: 22, weight: .semibold, design: .monospaced))
                Spacer()
                Text("Баланс \(a.fairness)/100").font(.system(size: 22, weight: .semibold, design: .rounded))
            }
        }
        .foregroundStyle(Color(white: 0.1))
        .padding(28)
        .frame(width: 776)
        .background(Color(red: 0.98, green: 0.96, blue: 0.91))
    }
}

struct FairnessBadge: View {
    let value: Int
    var color: Color {
        switch value {
        case 85...: return .green
        case 65..<85: return .yellow
        case 45..<65: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Gauge(value: Double(value), in: 0...100) {
                Text("Баланс")
            } currentValueLabel: {
                Text("\(value)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            .scaleEffect(0.8)
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 0) {
                Text("Баланс").font(.caption).foregroundStyle(.secondary)
                Text(BoardAnalysis.fairnessLabel(value)).font(.subheadline.weight(.semibold))
            }
        }
    }
}

// MARK: - Analysis panel

struct StatsPanel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let a = model.analysis
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(a.positives, id: \.self) { line in
                        Label(line, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    ForEach(a.issues, id: \.self) { line in
                        Label(line, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Оцінка карти: \(a.fairness)/100", systemImage: "scalemass")
            }

            GroupBox {
                Chart(a.resourceStats) { stat in
                    BarMark(x: .value("Ресурс", stat.resource.emoji + " " + stat.resource.cardName),
                            y: .value("Крапки", stat.pips))
                        .foregroundStyle(stat.resource.color)
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(stat.pips)").font(.caption2.weight(.bold))
                        }
                }
                .chartLegend(.hidden)
                .frame(height: 170)
                Text("Сума крапок на жетонах = як часто ресурс приходить. Більше — краще.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                Label("Ймовірність ресурсів", systemImage: "chart.bar.fill")
            }

            GroupBox {
                VStack(spacing: 8) {
                    ForEach(a.spots) { spot in
                        HStack(spacing: 10) {
                            Text("\(spot.rank)")
                                .font(.system(.callout, design: .rounded).weight(.black))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color.yellow))
                                .foregroundStyle(.black)
                            Text(spot.hexes.map { "\($0.resource.emoji)\($0.number ?? 0)" }.joined(separator: " + "))
                                .font(.system(.body, design: .rounded))
                            if let h = spot.harbor {
                                Text("⚓︎ \(h.title)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(spot.pips) ●")
                                .font(.callout.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Показати на карті") { model.overlay = .spots }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } label: {
                Label("Найкращі місця для поселень", systemImage: "house.fill")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.board.harbors.sorted { ($0.resource?.rawValue ?? "") < ($1.resource?.rawValue ?? "") }) { h in
                        Text(h.resource.map { "\($0.emoji) \($0.cardName) — 2:1" } ?? "⚓︎ Будь-який ресурс — 3:1")
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Label("Гавані", systemImage: "ferry.fill")
            }
        }
    }
}

// MARK: - Code entry

struct CodeEntryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Напр. S3F12-K9X2QA", text: $code)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        #endif
                        .onSubmit(open)
                } footer: {
                    Text(failed ? "Не вдалося розпізнати код." :
                         "Код містить налаштування і seed — та сама карта з’явиться на будь-якому пристрої. «BEGINNER» — стартова карта з правил.")
                        .foregroundStyle(failed ? .red : .secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Код карти")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Відкрити", action: open).disabled(code.isEmpty) }
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 240)
        #endif
    }

    private func open() {
        if model.load(code: code) { dismiss() } else { failed = true }
    }
}
