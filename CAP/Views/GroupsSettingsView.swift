import SwiftUI

struct GroupsSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draftName = ""
    @State private var draftColorIndex = 0
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let colorChoices = ClipboardGroup.defaultPalette

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Crea un gruppo")
                    .font(.headline)

                TextField("Nome (es. Lavoro, Codice…)", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addGroup() }

                HStack(spacing: 8) {
                    Text("Colore")
                        .foregroundStyle(.secondary)
                    ForEach(colorChoices.indices, id: \.self) { index in
                        let hex = colorChoices[index]
                        Circle()
                            .fill(Color(hex: hex) ?? .accentColor)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        draftColorIndex == index ? Color.primary : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .onTapGesture { draftColorIndex = index }
                    }
                }

                Button("Crea gruppo") {
                    addGroup()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let successMessage {
                    Text(successMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)

            if !appState.sortedGroups.isEmpty {
                Divider()
                ForEach(appState.sortedGroups) { group in
                    GroupEditorRow(group: group)
                }
                .onDelete(perform: deleteGroups)
            }
        } header: {
            Text("Gruppi")
        } footer: {
            Text("Ordine dall’alto verso il basso = ⌘1, ⌘2, … (max 9). Elimina con swipe o tasto Delete.")
                .font(.caption)
        }
    }

    private func addGroup() {
        errorMessage = nil
        successMessage = nil
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let hex = colorChoices[draftColorIndex]
        do {
            _ = try appState.addGroup(name: name, colorHex: hex)
            draftName = ""
            successMessage = "Gruppo «\(name)» creato."
        } catch {
            errorMessage = "Errore: \(error.localizedDescription)"
        }
    }

    private func deleteGroups(at offsets: IndexSet) {
        let ordered = appState.sortedGroups
        for index in offsets {
            try? appState.deleteGroup(id: ordered[index].id)
        }
        if case .group(let id) = appState.activeScope,
           offsets.contains(where: { ordered[$0].id == id }) {
            appState.selectScope(.general)
        }
    }
}

private struct GroupEditorRow: View {
    @EnvironmentObject private var appState: AppState
    let group: ClipboardGroup
    @State private var name: String

    init(group: ClipboardGroup) {
        self.group = group
        _name = State(initialValue: group.name)
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(group.swiftUIColor)
                .frame(width: 12, height: 12)
            TextField("Nome", text: $name)
                .onSubmit { persist() }
            if let label = appState.shortcutLabel(for: .group(group.id)) {
                Text(label)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .onDisappear { persist() }
    }

    private func persist() {
        var updated = group
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.name = trimmed.isEmpty ? group.name : trimmed
        try? appState.updateGroup(updated)
    }
}
