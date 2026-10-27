import AppKit
import Carbon.HIToolbox
import CoreGraphics
import UniformTypeIdentifiers

enum PasteService {
    private static var suppressNextCapture = false
    private static var deliverInFlight = false
    private static var lastDeliverStartedAt: Date?
    private static let deliverDebounce: TimeInterval = 0.6

    static func writeToPasteboard(_ record: ClippingRecord) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch record.payloadFormat {
        case .plainText:
            if let text = record.plainText ?? String(data: record.payload, encoding: .utf8) {
                pb.setString(text, forType: .string)
            }
        case .rtf:
            pb.setData(record.payload, forType: .rtf)
            if let text = record.plainText { pb.setString(text, forType: .string) }
        case .html:
            pb.setData(record.payload, forType: .html)
            if let text = record.plainText { pb.setString(text, forType: .string) }
        case .png, .tiff:
            if let image = NSImage(data: record.payload) {
                pb.writeObjects([image])
            } else {
                let type: NSPasteboard.PasteboardType =
                    record.payloadFormat == .tiff ? .tiff : .png
                pb.setData(record.payload, forType: type)
            }
        }
        let suppressDuration: TimeInterval = record.payloadFormat.isImage ? 1.0 : 0.5
        suppressNextCapture = true
        DispatchQueue.main.asyncAfter(deadline: .now() + suppressDuration) {
            suppressNextCapture = false
        }
    }

    @MainActor
    static func paste(_ record: ClippingRecord, completion: (() -> Void)? = nil) {
        guard !deliverInFlight else {
            completion?()
            return
        }
        writeToPasteboard(record)
        deliverToTargetApplication(for: record, completion: completion)
    }

    @MainActor
    static func deliverToTargetApplication(
        for record: ClippingRecord? = nil,
        completion: (() -> Void)? = nil
    ) {
        let now = Date()
        if deliverInFlight {
            completion?()
            return
        }
        if let lastDeliverStartedAt, now.timeIntervalSince(lastDeliverStartedAt) < deliverDebounce {
            completion?()
            return
        }
        lastDeliverStartedAt = now
        deliverInFlight = true

        let target = PasteTargetTracker.resolvedTarget()
        let isImage = record?.payloadFormat.isImage == true
        let pasteDelay: TimeInterval = isImage ? 0.45 : 0.35

        AppCoordinator.closeAllPanels()

        let finish: () -> Void = {
            deliverInFlight = false
            completion?()
        }

        let sendPaste: () -> Void = {
            switch performPasteIntoTarget() {
            case .success:
                break
            case .missingAccessibility:
                PasteDeliveryNotice.showAccessibilityRequiredOnce()
            case .failed:
                PasteDeliveryNotice.showPasteFailedOnce()
            }
            finish()
        }

        if let target {
            target.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteDelay) {
            if let target, !target.isActive {
                target.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NSApp.hide(nil)
                    sendPaste()
                }
            } else {
                NSApp.hide(nil)
                sendPaste()
            }
        }
    }

    private enum PasteDeliveryResult {
        case success
        case missingAccessibility
        case failed
    }

    /// Un solo incolla: AX Paste se possibile, altrimenti un ⌘V simulato (mai entrambi).
    @MainActor
    private static func performPasteIntoTarget() -> PasteDeliveryResult {
        guard AccessibilityAuthorization.isTrusted else {
            return .missingAccessibility
        }

        if AccessibilityPaste.pasteIntoFocusedElement() {
            return .success
        }

        simulateCommandV()
        return .success
    }

    private static func simulateCommandV() {
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    static var shouldSuppressCapture: Bool { suppressNextCapture }
}

@MainActor
enum PasteDeliveryNotice {
    private static var didShowAccessibilityAlert = false
    private static var didShowPasteFailedAlert = false

    static func showAccessibilityRequiredOnce() {
        guard !didShowAccessibilityAlert else { return }
        didShowAccessibilityAlert = true

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Abilita CAP in Accessibilità"
        alert.informativeText = """
        In Accessibilità premi + e scegli questa CAP.app (Finder + Impostazioni si aprono ora). \
        Poi esci e riavvia CAP una volta.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
        AccessibilityAuthorization.openRegistrationAssistant()
    }

    static func showPasteFailedOnce() {
        guard !didShowPasteFailedAlert else { return }
        didShowPasteFailedAlert = true

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Incolla automatico non riuscito"
        alert.informativeText = "Il contenuto è negli appunti: puoi usare ⌘V manualmente."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private extension PayloadFormat {
    var isImage: Bool {
        switch self {
        case .png, .tiff: return true
        default: return false
        }
    }
}
