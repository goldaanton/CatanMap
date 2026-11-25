import SwiftUI

struct HistoryScreen: View {
    @Environment(AppModel.self) private var model
    @State private var favoritesOnly = false

    private var items: [Board] {
        favoritesOnly ? model.history.filter(\.isFavorite) : model.history
    }

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    ContentUnavailableView(favoritesOnly ? "Немає обраних карт" : "Історія порожня",
                                           systemImage: favoritesOnly ? "star" : "clock",
                                           description: Text("Позначайте вдалі карти зірочкою, щоб не загубити."))
                }
                ForEach(items) { board in
                    row(board)
                        .contentShape(Rectangle())
                        .onTapGesture { model.load(board) }
                        .swipeActions(edge: .leading) {
                            Button {
                                model.toggleFavorite(board)
                            } label: {
                                Label("Обране", systemImage: board.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) { model.delete(board) } label: {
                                Label("Видалити", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button("Відкрити", systemImage: "map") { model.load(board) }
                            Button(board.isFavorite ? "Прибрати з обраного" : "В обране", systemImage: "star") {
                                model.toggleFavorite(board)
                            }
                            Button("Скопіювати код", systemImage: "doc.on.doc") { copyToClipboard(board.code) }
                            Divider()
                            Button("Видалити", systemImage: "trash", role: .destructive) { model.delete(board) }
                        }
                }
            }
            .navigationTitle("Історія")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Toggle(isOn: $favoritesOnly) {
                        Label("Лише обрані", systemImage: favoritesOnly ? "star.fill" : "star")
                    }
                    Button(role: .destructive) {
                        model.clearHistory()
                    } label: {
                        Label("Очистити (крім обраних)", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func row(_ board: Board) -> some View {
        let fairness = BoardAnalysis(board: board).fairness
        return HStack(spacing: 14) {
            BoardView(board: board)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(board.displayCode).font(.system(.headline, design: .monospaced))
                    if board.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    if board.id == model.board.id {
                        Text("зараз").font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    }
                }
                Text("\(board.settings.size.title) · \(board.created.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(fairness)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(fairness >= 85 ? Color.green : (fairness >= 65 ? Color.yellow : Color.orange))
        }
        .padding(.vertical, 4)
    }
}
