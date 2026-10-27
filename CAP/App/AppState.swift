import AppKit
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var clippings: [ClippingRecord] = []
    @Published private(set) var groups: [ClipboardGroup] = []
    @Published var isRecording = true
    @Published var searchQuery = ""
    @Published var activeScope: HistoryScope = .general
    @Published var selectedClippingID: UUID?

    let store = ClippingStore()
    private var monitor: PasteboardMonitor?
    private var cancellables = Set<AnyCancellable>()

    init() {
        AppCoordinator.appState = self
        reloadGroups()
        reloadFromStore()
        startMonitoring()
    }

    var sortedGroups: [ClipboardGroup] {
        groups.sorted { $0.sortOrder < $1.sortOrder }
    }

    var filteredClippings: [ClippingRecord] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard activeScope == .general, !q.isEmpty else { return clippings }
        return clippings.filter {
            ($0.plainText ?? "").localizedCaseInsensitiveContains(q)
                || $0.displayTitle.localizedCaseInsensitiveContains(q)
        }
    }

    func title(for scope: HistoryScope) -> String {
        switch scope {
        case .general: return "Generale"
        case .group(let id):
            return groups.first(where: { $0.id == id })?.name ?? "Gruppo"
        }
    }

    func group(for id: UUID) -> ClipboardGroup? {
        groups.first(where: { $0.id == id })
    }

    func shortcutLabel(for scope: HistoryScope) -> String? {
        switch scope {
        case .general: return Preferences.generalScopeShortcut.title
        case .group(let id):
            let sorted = sortedGroups
            guard let index = sorted.firstIndex(where: { $0.id == id }), index < 9 else { return nil }
            return "⌘\(index + 1)"
        }
    }

    func reloadGroups() {
        groups = (try? store.fetchGroups()) ?? []
    }

    func reloadFromStore() {
        reloadScope(activeScope)
    }

    func selectScope(_ scope: HistoryScope) {
        activeScope = scope
        if scope != .general {
            searchQuery = ""
        }
        reloadScope(scope)
    }

    func selectScopeKeyboardIndex(_ index: Int) {
        guard index >= 1, index <= 9 else { return }
        let sorted = sortedGroups
        guard index <= sorted.count else { return }
        selectScope(.group(sorted[index - 1].id))
    }

    func paste(_ clipping: ClippingRecord) {
        if Preferences.closePanelAfterPaste {
            if let historyPanel = AppCoordinator.historyPanel {
                historyPanel.performPaste(clipping)
            } else {
                PasteService.paste(clipping)
            }
        } else {
            PasteService.writeToPasteboard(clipping)
        }
    }

    func pasteSelected() {
        guard let id = selectedClippingID,
              let clipping = filteredClippings.first(where: { $0.id == id }) else { return }
        paste(clipping)
    }

    func prepareForKeyboardNavigation() {
        ensureSelection()
    }

    func selectClipping(_ id: UUID?) {
        selectedClippingID = id
    }

    func selectNextClipping() {
        let items = filteredClippings
        guard !items.isEmpty else {
            selectedClippingID = nil
            return
        }
        guard let current = selectedClippingID,
              let idx = items.firstIndex(where: { $0.id == current }) else {
            selectedClippingID = items[0].id
            return
        }
        let next = min(idx + 1, items.count - 1)
        selectedClippingID = items[next].id
    }

    func selectPreviousClipping() {
        let items = filteredClippings
        guard !items.isEmpty else {
            selectedClippingID = nil
            return
        }
        guard let current = selectedClippingID,
              let idx = items.firstIndex(where: { $0.id == current }) else {
            selectedClippingID = items[0].id
            return
        }
        let prev = max(idx - 1, 0)
        selectedClippingID = items[prev].id
    }

    func moveToGroup(_ clipping: ClippingRecord, groupId: UUID?) {
        guard let updated = try? store.setGroupId(id: clipping.id, groupId: groupId) else { return }
        removeFromCurrentList(clipping.id)
        switch activeScope {
        case .general where groupId == nil:
            clippings.insert(updated, at: 0)
        case .group(let activeId) where activeId == groupId:
            clippings.insert(updated, at: 0)
        default:
            break
        }
        ensureSelection()
    }

    func toggleStar(_ clipping: ClippingRecord) {
        guard let updated = try? store.setStarred(id: clipping.id, starred: !clipping.isStarred) else { return }
        replaceInList(updated)
    }

    func delete(_ clipping: ClippingRecord) {
        try? store.delete(id: clipping.id)
        clippings.removeAll { $0.id == clipping.id }
        ensureSelection()
    }

    func clearActiveScope() {
        try? store.clearScope(activeScope)
        clippings = []
        selectedClippingID = nil
    }

    func clearHistory() {
        try? store.deleteAll()
        clippings = []
        selectedClippingID = nil
    }

    func deleteActiveGroup() throws {
        guard case .group(let id) = activeScope else { return }
        try deleteGroup(id: id)
        selectScope(.general)
    }

    func deleteGroup(id: UUID) throws {
        try store.deleteGroup(id: id)
        reloadGroups()
    }

    @discardableResult
    func addGroup(name: String, colorHex: String) throws -> ClipboardGroup {
        try store.ensureGroupsSchema()
        let group = try store.createGroup(name: name, colorHex: colorHex)
        reloadGroups()
        return group
    }

    func updateGroup(_ group: ClipboardGroup) throws {
        try store.updateGroup(group)
        reloadGroups()
    }

    func reorderGroups(_ ordered: [ClipboardGroup]) throws {
        try store.setGroupOrders(ordered)
        reloadGroups()
    }

    private func startMonitoring() {
        let monitor = PasteboardMonitor { [weak self] snapshot in
            Task { @MainActor in
                self?.handleNewSnapshot(snapshot)
            }
        }
        self.monitor = monitor
        monitor.start()
    }

    private func handleNewSnapshot(_ snapshot: PasteboardSnapshot) {
        guard isRecording else { return }
        if let bundleID = snapshot.sourceBundleID, Preferences.ignoredBundleIDs.contains(bundleID) {
            return
        }
        guard let record = try? store.insert(snapshot: snapshot) else { return }
        if activeScope == .general, record.groupId == nil {
            clippings.removeAll { $0.id == record.id }
            clippings.insert(record, at: 0)
            selectedClippingID = record.id
        }
        trimStoreIfNeeded()
    }

    private func reloadScope(_ scope: HistoryScope) {
        clippings = (try? store.fetch(scope: scope, limit: Preferences.maxHistoryCount)) ?? []
        ensureSelection()
    }

    private func ensureSelection() {
        let items = filteredClippings
        if items.isEmpty {
            selectedClippingID = nil
            return
        }
        if let selected = selectedClippingID, items.contains(where: { $0.id == selected }) {
            return
        }
        selectedClippingID = items.first?.id
    }

    private func replaceInList(_ record: ClippingRecord) {
        if let idx = clippings.firstIndex(where: { $0.id == record.id }) {
            clippings[idx] = record
        }
    }

    private func removeFromCurrentList(_ id: UUID) {
        clippings.removeAll { $0.id == id }
        if selectedClippingID == id {
            ensureSelection()
        }
    }

    private func trimStoreIfNeeded() {
        try? store.trimToMaxCount(Preferences.maxHistoryCount)
    }
}
