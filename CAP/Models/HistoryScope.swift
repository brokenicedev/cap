import Foundation

enum HistoryScope: Equatable, Hashable, Identifiable {
    case general
    case group(UUID)

    var id: String {
        switch self {
        case .general: return "general"
        case .group(let id): return id.uuidString
        }
    }

    var groupId: UUID? {
        if case .group(let id) = self { return id }
        return nil
    }
}
