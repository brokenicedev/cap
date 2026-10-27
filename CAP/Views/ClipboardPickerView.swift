import AppKit
import SwiftUI

struct ClipboardPickerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isSearchVisible = false
    @State private var showDeleteGroupConfirm = false
    @State private var showClearConfirm = false
    @FocusState private var searchFocused: Bool

    private var scopeBinding: Binding<HistoryScope> {
        Binding(
            get: { appState.activeScope },
            set: { newScope in
                appState.selectScope(newScope)
                if newScope != .general { isSearchVisible = false }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.35)
            clippingList
            Divider().opacity(0.35)
            bottomToolbar
        }
        .frame(width: HistoryPanelMetrics.width, height: HistoryPanelMetrics.height)
        .preferredColorScheme(.dark)
        .focusable(true)
        .focusEffectDisabled()
        .onKeyPress(.upArrow) {
            appState.selectPreviousClipping()
            return .handled
        }
        .onKeyPress(.downArrow) {
            appState.selectNextClipping()
            return .handled
        }
        .alert("Eliminare il gruppo?", isPresented: $showDeleteGroupConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina", role: .destructive) {
                try? appState.deleteActiveGroup()
            }
        } message: {
            if case .group(let id) = appState.activeScope {
                Text("Gli elementi di «\(appState.title(for: .group(id)))» torneranno in Generale.")
            }
        }
        .alert("Svuotare Generale?", isPresented: $showClearConfirm) {
            Button("Annulla", role: .cancel) {}
            Button("Svuota", role: .destructive) {
                appState.clearActiveScope()
            }
        } message: {
            Text("Tutti gli elementi in Generale saranno eliminati.")
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            ScopePickerMenu(selection: scopeBinding)

            Spacer(minLength: 0)

            if appState.activeScope == .general {
                HStack(spacing: 6) {
                    if isSearchVisible {
                        TextField("Cerca", text: $appState.searchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .focused($searchFocused)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .frame(width: 196)
                    }

                    HeaderIconButton(
                        systemName: isSearchVisible ? "xmark" : "magnifyingglass",
                        help: isSearchVisible ? "Chiudi ricerca" : "Cerca",
                        isActive: isSearchVisible
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            if isSearchVisible {
                                isSearchVisible = false
                                appState.searchQuery = ""
                            } else {
                                isSearchVisible = true
                                searchFocused = true
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            PanelToolbarButton(systemName: "gearshape", help: "Impostazioni", isActive: false) {
                SettingsWindowController.show()
            }
            .frame(maxWidth: .infinity)

            PanelToolbarButton(
                systemName: appState.isRecording ? "pause.fill" : "play.fill",
                help: appState.isRecording ? "Pausa registrazione" : "Riprendi registrazione",
                isActive: appState.isRecording
            ) {
                appState.isRecording.toggle()
            }
            .frame(maxWidth: .infinity)

            PanelToolbarButton(systemName: "trash", help: destructiveToolbarHelp, isActive: false) {
                performDestructiveToolbarAction()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.28))
    }

    private var destructiveToolbarHelp: String {
        switch appState.activeScope {
        case .general: return "Svuota Generale"
        case .group: return "Elimina gruppo"
        }
    }

    private func performDestructiveToolbarAction() {
        switch appState.activeScope {
        case .general:
            showClearConfirm = true
        case .group:
            showDeleteGroupConfirm = true
        }
    }

    @ViewBuilder
    private var clippingList: some View {
        if appState.filteredClippings.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "doc.on.clipboard", description: Text(emptySubtitle))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(appState.filteredClippings.enumerated()), id: \.element.id) { index, clipping in
                            ClippingRow(
                                clipping: clipping,
                                index: index + 1,
                                groups: appState.sortedGroups,
                                onAssign: { groupId in appState.moveToGroup(clipping, groupId: groupId) }
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(rowBackground(for: clipping))
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    appState.paste(clipping)
                                }
                            )
                            .onTapGesture(count: 1) {
                                appState.selectClipping(clipping.id)
                            }
                            .contextMenu {
                                Button("Incolla") { appState.paste(clipping) }
                                Button(clipping.isStarred ? "Rimuovi preferito" : "Preferito") {
                                    appState.toggleStar(clipping)
                                }
                                Divider()
                                Button("Elimina", role: .destructive) { appState.delete(clipping) }
                            }
                            .id(clipping.id)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.visible)
                .onChange(of: appState.selectedClippingID) { _, newID in
                    guard let newID else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyTitle: String {
        switch appState.activeScope {
        case .general: return "Nessun elemento"
        case .group: return "Gruppo vuoto"
        }
    }

    private func rowBackground(for clipping: ClippingRecord) -> some View {
        let selected = appState.selectedClippingID == clipping.id
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        selected ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.08),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
    }

    private var emptySubtitle: String {
        switch appState.activeScope {
        case .general:
            return "Le copie finiscono qui finché non le sposti in un gruppo."
        case .group(let id):
            return "Usa il pulsante gruppo a destra per spostare elementi in «\(appState.title(for: .group(id)))»."
        }
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let help: String
    var isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.75))
                .frame(width: 28, height: 24)
                .background(isHovered ? Color.primary.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct PanelToolbarButton: View {
    let systemName: String
    let help: String
    var isActive: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.82))
                .frame(width: 32, height: 24)
                .background(isHovered ? Color.primary.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

private struct ClippingRow: View {
    let clipping: ClippingRecord
    let index: Int
    let groups: [ClipboardGroup]
    let onAssign: (UUID?) -> Void
    @State private var isAssignPickerOpen = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            rowLeadingVisual

            VStack(alignment: .leading, spacing: 3) {
                if clipping.showsImagePreview {
                    if let caption = imageCaption {
                        Text(caption)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Immagine")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(clipping.listPreviewText)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 5) {
                groupAssignButton
                Text("\(index)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .monospacedDigit()
            }
            .padding(.top, 1)
        }
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var rowLeadingVisual: some View {
        if clipping.showsImagePreview {
            ClippingThumbnailView(
                clipping: clipping,
                height: imageCaption == nil ? 62 : 54,
                maxWidth: imageCaption == nil ? 104 : 88
            )
        } else if let hexColor = clipping.listHexColor {
            ClippingColorSwatch(color: hexColor, size: 16)
        }
    }

    private var groupAssignButton: some View {
        Button {
            if groups.isEmpty {
                SettingsWindowController.show()
            } else {
                isAssignPickerOpen = true
            }
        } label: {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(groupMarkerFill)
                    .frame(width: 10, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .strokeBorder(groupMarkerStroke, lineWidth: clipping.groupId == nil ? 1.25 : 0)
                    )
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(groups.isEmpty ? "Crea gruppi in Impostazioni" : "Assegna a un gruppo")
        .popover(isPresented: $isAssignPickerOpen, arrowEdge: .bottom) {
            GroupScopePickerPanel(
                groups: groups,
                assignedGroupId: clipping.groupId,
                showsShortcuts: false,
                shortcutProvider: { _ in nil },
                onPick: { groupId in onAssign(groupId) }
            )
        }
    }

    private var groupMarkerFill: Color {
        guard let groupId = clipping.groupId,
              let group = groups.first(where: { $0.id == groupId }) else {
            return Color.clear
        }
        return group.swiftUIColor
    }

    private var groupMarkerStroke: Color {
        Color.secondary.opacity(0.5)
    }

    private var imageCaption: String? {
        guard let plain = clipping.plainText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !plain.isEmpty else { return nil }
        return plain
    }
}
