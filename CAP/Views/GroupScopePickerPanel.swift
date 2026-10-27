import SwiftUI

/// Elenco gruppi in popover (i `Menu` SwiftUI su macOS non disegnano bene le viste custom).
struct GroupScopePickerPanel: View {
    let groups: [ClipboardGroup]
    var assignedGroupId: UUID?
    var showsShortcuts: Bool
    var shortcutProvider: (HistoryScope) -> String?
    /// Se presente, mostra una stellina accanto a ogni gruppo.
    var favoriteGroupIDs: Set<UUID> = []
    var onToggleFavorite: ((UUID) -> Void)?
    let onPick: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            pickRow(title: "Generale", scope: .general, groupId: nil)

            if !groups.isEmpty {
                Divider().opacity(0.35)
                ForEach(groups) { group in
                    pickRow(title: group.name, scope: .group(group.id), groupId: group.id)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 176)
    }

    private func pickRow(title: String, scope: HistoryScope, groupId: UUID?) -> some View {
        let selected = assignedGroupId == groupId
        return HStack(spacing: 4) {
            pickButton(title: title, scope: scope, groupId: groupId, selected: selected)
            if let onToggleFavorite {
                if let groupId {
                    FavoriteStarButton(isFavorite: favoriteGroupIDs.contains(groupId)) {
                        onToggleFavorite(groupId)
                    }
                } else {
                    // Mantiene allineate le righe (Generale non ha stellina).
                    Color.clear.frame(width: 20, height: 20)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(selected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func pickButton(title: String, scope: HistoryScope, groupId: UUID?, selected: Bool) -> some View {
        Button {
            onPick(groupId)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                ScopeColorGlyph(scope: scope, groups: groups)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 13))
                Spacer(minLength: 8)
                if showsShortcuts, let shortcut = shortcutProvider(scope) {
                    Text(shortcut)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct FavoriteStarButton: View {
    let isFavorite: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary.opacity(isHovered ? 0.9 : 0.5))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isFavorite ? "Rimuovi dai preferiti" : "Mostra accanto alla selezione")
    }
}
