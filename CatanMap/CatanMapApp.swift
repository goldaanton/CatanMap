import SwiftUI

@main
struct CatanMapApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .commands {
            CommandMenu("Карта") {
                Button("Нова карта") { model.generate() }
                Button("Стартова карта з правил") { model.loadBeginner() }
                Divider()
                Button("Скопіювати код карти") { copyToClipboard(model.board.code) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        #endif
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        TabView(selection: $model.tab) {
            MapScreen()
                .tabItem { Label("Карта", systemImage: "hexagon.fill") }
                .tag(AppTab.map)
            DiceScreen()
                .tabItem { Label("Кубики", systemImage: "dice.fill") }
                .tag(AppTab.dice)
            HistoryScreen()
                .tabItem { Label("Історія", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)
        }
    }
}

#Preview {
    ContentView().environment(AppModel())
}
