import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Пресети") {
                    HStack {
                        presetButton("Турнір", icon: "trophy", .tournament)
                        presetButton("Класика", icon: "book.closed", .classic)
                        presetButton("Хаос", icon: "tornado", .chaos)
                    }
                    .buttonStyle(.bordered)
                }

                Section("Поле") {
                    Picker("Кількість гравців", selection: $model.settings.size) {
                        ForEach(BoardSize.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Пустеля в центрі", isOn: $model.settings.desertInCenter)
                    Toggle("Без однакових ресурсів поруч", isOn: $model.settings.noAdjacentSameResource)
                }

                Section {
                    Picker("Розкладка чисел", selection: $model.settings.numberMode) {
                        ForEach(NumberMode.allCases) { Text($0.title).tag($0) }
                    }
                    Group {
                        Toggle("6 і 8 не поруч", isOn: $model.settings.noAdjacentRed)
                        Toggle("Однакові числа не поруч", isOn: $model.settings.noAdjacentSameNumber)
                        Toggle("Рідкісні (2, 3, 11, 12) не скупчуються", isOn: $model.settings.spreadRareNumbers)
                        Toggle("Рівна ймовірність ресурсів", isOn: $model.settings.balanceResources)
                        Toggle("Обмежити «гарячі» перехрестя", isOn: $model.settings.pipCapOn)
                        if model.settings.pipCapOn {
                            Stepper("Максимум крапок на перехресті: \(model.settings.maxIntersectionPips)",
                                    value: $model.settings.maxIntersectionPips, in: 10...14)
                        }
                    }
                    .disabled(spiralActive)
                } header: {
                    Text("Числа")
                } footer: {
                    if spiralActive {
                        Text("Спіраль — офіційний спосіб з правил: жетони A–R викладаються від кута по колу. Правила балансу чисел при цьому не діють.")
                    } else if model.settings.numberMode == .spiral {
                        Text("Спіраль доступна лише для поля 3–4 гравці, тож тут числа розкладаються з правилами.")
                    } else {
                        Text("Генератор перебирає тисячі варіантів і обирає той, що найкраще відповідає увімкненим правилам.")
                    }
                }

                Section {
                    Button {
                        model.generate()
                        dismiss()
                    } label: {
                        Label("Згенерувати з цими налаштуваннями", systemImage: "shuffle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Налаштування")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 600)
        #endif
    }

    private var spiralActive: Bool {
        model.settings.numberMode == .spiral && model.settings.size == .standard
    }

    private func presetButton(_ title: String, icon: String, _ preset: GeneratorSettings) -> some View {
        Button {
            var p = preset
            p.size = model.settings.size
            model.settings = p
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
