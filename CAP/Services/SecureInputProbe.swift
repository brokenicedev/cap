import ApplicationServices
import Carbon
import Foundation

/// Rileva Secure Event Input / campi password (richiede Accessibilità per l’elemento AX).
enum SecureInputProbe {
    /// macOS sta proteggendo la tastiera (tipico dei campi password).
    static var isSecureEventInputEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    /// Elemento con focus è un campo password / secure text field.
    static var isPasswordFieldFocused: Bool {
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
        return isSecureTextElement(element)
    }

    /// Blocca l’apertura del pannello se l’utente non ha abilitato l’opzione.
    static var shouldBlockPanelOpen: Bool {
        guard !Preferences.openPanelInPasswordFields else { return false }
        return isSecureEventInputEnabled || isPasswordFieldFocused
    }

    private static func isSecureTextElement(_ element: AXUIElement) -> Bool {
        if stringAttribute(element, kAXRoleAttribute) == "AXSecureTextField" {
            return true
        }
        if stringAttribute(element, kAXSubroleAttribute) == "AXSecureTextField" {
            return true
        }
        return false
    }

    private static func stringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        guard result == .success, let value else { return nil }
        return value as? String
    }
}
