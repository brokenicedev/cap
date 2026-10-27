import Foundation

enum BuildFlavor {
    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var menuBarAccessibilityLabel: String {
        isDebug ? "\(AppIdentity.name) Debug" : AppIdentity.name
    }

    static var panelTitle: String {
        isDebug ? "\(AppIdentity.name) · Debug" : AppIdentity.name
    }
}
