import ApplicationServices
import AppKit

enum AccessibilityPaste {
    /// Incolla dal pasteboard generale nel campo con focus (richiede Accessibilità).
    static func pasteIntoFocusedElement() -> Bool {
        guard AccessibilityAuthorization.isTrusted else { return false }

        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard copyResult == .success, let focusedValue else { return false }

        let element = focusedValue as! AXUIElement
        let pasteResult = AXUIElementPerformAction(element, "AXPaste" as CFString)
        return pasteResult == .success
    }

    static func pasteViaSystemEventsKeystroke() -> Bool {
        guard AccessibilityAuthorization.isTrusted else { return false }
        var error: NSDictionary?
        let script = NSAppleScript(source: """
        tell application "System Events"
            keystroke "v" using command down
        end tell
        """)
        script?.executeAndReturnError(&error)
        return error == nil
    }
}
