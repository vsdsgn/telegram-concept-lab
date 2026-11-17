import UIKit

enum SwipeSide: String, Codable {
    case leading
    case trailing
}
enum ChatAction: String, CaseIterable, Codable, Hashable {
    case read
    case pin
    case archive
    case mute
    case delete
    case favorite

    var title: String {
        switch self {
        case .read: "Mark read"
        case .pin: "Pin"
        case .archive: "Archive"
        case .mute: "Mute"
        case .delete: "Delete"
        case .favorite: "Favorite"
        }
    }

    var shortTitle: String {
        switch self {
        case .read: "Read"
        case .pin: "Pin"
        case .archive: "Archive"
        case .mute: "Mute"
        case .delete: "Delete"
        case .favorite: "Favorite"
        }
    }

    var symbolName: String {
        switch self {
        case .read: "envelope.open.fill"
        case .pin: "pin.fill"
        case .archive: "archivebox.fill"
        case .mute: "speaker.slash.fill"
        case .delete: "trash.fill"
        case .favorite: "star.fill"
        }
    }

    var tintColor: UIColor {
        switch self {
        case .read: Palette.blue
        case .pin: Palette.orange
        case .archive: Palette.indigo
        case .mute: Palette.slate
        case .delete: Palette.destructive
        case .favorite: Palette.gold
        }
    }

    var isDestructive: Bool { self == .delete }
}

struct ActionConfiguration: Codable, Equatable {
    var leading: [ChatAction]
    var trailing: [ChatAction]

    static let defaults = ActionConfiguration(
        leading: [.read, .pin, .favorite],
        trailing: [.archive, .mute, .delete]
    )

    func actions(for side: SwipeSide) -> [ChatAction] {
        side == .leading ? leading : trailing
    }

    mutating func set(_ action: ChatAction, side: SwipeSide, index: Int) {
        guard (0..<3).contains(index) else { return }
        if side == .leading {
            leading[index] = action
        } else {
            trailing[index] = action
        }
    }
}

enum ActionConfigurationStore {
    private static let key = "multiActionSwipe.configuration.v1"

    static func load() -> ActionConfiguration {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let value = try? JSONDecoder().decode(ActionConfiguration.self, from: data),
            value.leading.count == 3,
            value.trailing.count == 3
        else {
            return .defaults
        }
        return value
    }

    static func save(_ configuration: ActionConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

struct ChatPreview: Identifiable, Equatable {
    let id: UUID
    let name: String
    var message: String
    let time: String
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var isFavorite: Bool
    let initials: String
    let avatarColor: UIColor

    static let mock: [ChatPreview] = [
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, name: "Maya Chen", message: "The interaction prototype is ready to review.", time: "10:42", unreadCount: 2, isPinned: true, isMuted: false, isFavorite: false, initials: "MC", avatarColor: Palette.blue),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, name: "Design Critique", message: "Jon: I like the third spring option best.", time: "09:18", unreadCount: 5, isPinned: false, isMuted: false, isFavorite: true, initials: "DC", avatarColor: Palette.indigo),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, name: "Noah Williams", message: "Can we test the action order on a smaller phone?", time: "Yesterday", unreadCount: 0, isPinned: false, isMuted: true, isFavorite: false, initials: "NW", avatarColor: Palette.orange),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!, name: "Weekend Plans", message: "Priya: Train leaves at 08:15.", time: "Yesterday", unreadCount: 8, isPinned: false, isMuted: false, isFavorite: false, initials: "WP", avatarColor: Palette.gold),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!, name: "Ava Thompson", message: "Sent a photo", time: "Mon", unreadCount: 0, isPinned: false, isMuted: false, isFavorite: false, initials: "AT", avatarColor: Palette.mint),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!, name: "iOS Builders", message: "Release build is green on the simulator.", time: "Sun", unreadCount: 12, isPinned: false, isMuted: true, isFavorite: false, initials: "IB", avatarColor: Palette.slate),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!, name: "Liam Garcia", message: "Thanks — see you tomorrow!", time: "Sat", unreadCount: 0, isPinned: false, isMuted: false, isFavorite: false, initials: "LG", avatarColor: Palette.coral),
        ChatPreview(id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!, name: "Research Notes", message: "4 new links saved for later.", time: "Fri", unreadCount: 4, isPinned: false, isMuted: false, isFavorite: true, initials: "RN", avatarColor: Palette.purple)
    ]
}
