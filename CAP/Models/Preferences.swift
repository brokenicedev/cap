import Foundation

enum Preferences {
    private static let defaults = UserDefaults.standard

    static var maxHistoryCount: Int {
        let value = defaults.integer(forKey: Keys.maxHistory)
        return value > 0 ? value : 500
    }

    static func setMaxHistoryCount(_ value: Int) {
        defaults.set(max(50, min(10_000, value)), forKey: Keys.maxHistory)
    }

    static var ignoredBundleIDs: Set<String> {
        Set(defaults.stringArray(forKey: Keys.ignoredApps) ?? [])
    }

    static func setIgnoredBundleIDs(_ ids: [String]) {
        defaults.set(ids, forKey: Keys.ignoredApps)
    }

    /// Chiude il pannello dopo incolla (click o Invio). Default: attivo.
    static var closePanelAfterPaste: Bool {
        if defaults.object(forKey: Keys.closeAfterPaste) == nil { return true }
        return defaults.bool(forKey: Keys.closeAfterPaste)
    }

    static func setClosePanelAfterPaste(_ value: Bool) {
        defaults.set(value, forKey: Keys.closeAfterPaste)
    }

    static var generalScopeShortcut: GeneralScopeShortcut {
        guard let raw = defaults.string(forKey: Keys.generalScopeShortcut),
              let value = GeneralScopeShortcut(rawValue: raw) else {
            return .commandShiftLessThan
        }
        return value
    }

    static func setGeneralScopeShortcut(_ value: GeneralScopeShortcut) {
        defaults.set(value.rawValue, forKey: Keys.generalScopeShortcut)
    }

    static func favoriteListName(slot: Int) -> String {
        let key = Keys.favoriteNamePrefix + String(slot)
        if let custom = defaults.string(forKey: key), !custom.isEmpty {
            return custom
        }
        return "Preferiti \(slot)"
    }

    static func setFavoriteListName(slot: Int, name: String) {
        defaults.set(name, forKey: Keys.favoriteNamePrefix + String(slot))
    }

    /// Copia le preferenze dal bundle `com.francesco.CopyAndPaste` (una tantum).
    static func migrateFromLegacyBundleIfNeeded() {
        guard !defaults.bool(forKey: Keys.legacyPreferencesMigrated) else { return }
        defaults.set(true, forKey: Keys.legacyPreferencesMigrated)

        let plist = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Preferences/\(AppIdentity.legacyBundleIdentifier).plist")
        guard FileManager.default.fileExists(atPath: plist.path),
              let legacy = NSDictionary(contentsOf: plist) as? [String: Any] else { return }

        for key in legacyPreferenceKeys where defaults.object(forKey: key) == nil {
            if let value = legacy[key] {
                defaults.set(value, forKey: key)
            }
        }
    }

    private static let legacyPreferenceKeys: [String] = {
        var keys = [
            Keys.maxHistory,
            Keys.ignoredApps,
            Keys.closeAfterPaste,
            Keys.generalScopeShortcut,
        ]
        for slot in 1 ... 9 {
            keys.append(Keys.favoriteNamePrefix + String(slot))
        }
        return keys
    }()

    private enum Keys {
        static let maxHistory = "maxHistoryCount"
        static let ignoredApps = "ignoredBundleIDs"
        static let favoriteNamePrefix = "favoriteListName_"
        static let closeAfterPaste = "closePanelAfterPaste"
        static let generalScopeShortcut = "generalScopeShortcut"
        static let legacyPreferencesMigrated = "migratedUserDefaultsFromLegacyBundle"
    }
}

enum GeneralScopeShortcut: String, CaseIterable, Identifiable {
    case commandShiftLessThan
    case commandZero
    case commandG

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commandShiftLessThan: return "⌘⇧,  (tasto <)"
        case .commandZero: return "⌘0"
        case .commandG: return "⌘G"
        }
    }
}
