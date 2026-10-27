import Carbon
import Foundation

final class GlobalHotKeyService {
    private var hotKeyRef: EventHotKeyRef?
    private let handler: () -> Void
    private var eventHandlerRef: EventHandlerRef?

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func register() {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let hotKeyID = EventHotKeyID(signature: OSType(0x43415045), id: UInt32(1)) // CAPE

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let service = Unmanaged<GlobalHotKeyService>.fromOpaque(userData).takeUnretainedValue()
                var hotID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotID
                )
                if hotID.id == 1 {
                    DispatchQueue.main.async { service.handler() }
                    return noErr
                }
                return OSStatus(eventNotHandledErr)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    deinit {
        unregister()
    }
}
