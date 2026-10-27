import SwiftUI

struct ScopePickerMenu: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: HistoryScope
    @State private var isHovered = false
    @State private var isPickerOpen = false

    var body: some View {
        Button {
            isPickerOpen = true
        } label: {
            HStack(spacing: 7) {
                ScopeColorGlyph(scope: selection, groups: appState.sortedGroups)
                    .frame(width: 10, height: 10)

                Text(appState.title(for: selection))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPickerOpen, arrowEdge: .bottom) {
            GroupScopePickerPanel(
                groups: appState.sortedGroups,
                assignedGroupId: selection.groupId,
                showsShortcuts: true,
                shortcutProvider: { scope in
                    switch scope {
                    case .general:
                        return Preferences.generalScopeShortcut.title
                    case .group:
                        return appState.shortcutLabel(for: scope)
                    }
                },
                onPick: { groupId in
                    if let groupId {
                        let scope = HistoryScope.group(groupId)
                        selection = scope
                        appState.selectScope(scope)
                    } else {
                        selection = .general
                        appState.selectScope(.general)
                    }
                }
            )
        }
    }
}

/// Indicatore colore (Generale = cerchio vuoto, gruppo = cerchio pieno).
struct ScopeColorGlyph: View {
    let scope: HistoryScope
    let groups: [ClipboardGroup]

    var body: some View {
        Group {
            switch scope {
            case .general:
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.25)
            case .group(let id):
                Circle()
                    .fill(groups.first(where: { $0.id == id })?.swiftUIColor ?? Color.accentColor)
            }
        }
        .frame(width: 10, height: 10)
    }
}

struct GroupScopeMenuRow: View {
    let title: String
    let scope: HistoryScope
    let groups: [ClipboardGroup]
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            ScopeColorGlyph(scope: scope, groups: groups)
            Text(title)
            Spacer(minLength: 12)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
            }
        }
    }
}
