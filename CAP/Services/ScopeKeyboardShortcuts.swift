import AppKit

enum ScopeKeyboardShortcuts {
    static func matchesGeneralShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else { return false }

        switch Preferences.generalScopeShortcut {
        case .commandShiftLessThan:
            if flags.contains(.shift), event.keyCode == 43 { return true }
            if event.charactersIgnoringModifiers == "<" { return true }
            if event.characters == "<" { return true }
            return false
        case .commandZero:
            return !flags.contains(.shift) && event.keyCode == 29
        case .commandG:
            let char = event.charactersIgnoringModifiers?.lowercased()
            return event.keyCode == 5 || char == "g"
        }
    }

    static func matchesGroupIndexShortcut(_ event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), !flags.contains(.shift) else { return nil }
        guard let chars = event.charactersIgnoringModifiers, let digit = Int(chars), (1...9).contains(digit) else {
            return nil
        }
        return digit
    }
}
