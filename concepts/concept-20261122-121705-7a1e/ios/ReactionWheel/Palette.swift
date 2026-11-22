import UIKit

enum Palette {
    static let chat = UIColor { $0.userInterfaceStyle == .dark ? hex(0x0F1419) : hex(0xEEF2F5) }
    static let bubbleIn = UIColor { $0.userInterfaceStyle == .dark ? hex(0x1C242D) : .white }
    static let bubbleOut = UIColor { $0.userInterfaceStyle == .dark ? hex(0x2B4F7E) : hex(0xDCEBFF) }
    static let primary = UIColor { $0.userInterfaceStyle == .dark ? hex(0xF2F5F7) : hex(0x111418) }
    // Raised from the draft dark token for WCAG contrast at small Dynamic Type sizes.
    static let secondary = UIColor { $0.userInterfaceStyle == .dark ? hex(0xAEB8C3) : hex(0x56616D) }
    static let accent = UIColor { $0.userInterfaceStyle == .dark ? hex(0x69ADFF) : hex(0x1769C2) }
    static let plate = UIColor { $0.userInterfaceStyle == .dark ? hex(0x232C36).withAlphaComponent(0.98) : UIColor.white.withAlphaComponent(0.96) }
    static let selected = UIColor { $0.userInterfaceStyle == .dark ? hex(0x34506F) : hex(0xE3EEFF) }
    static let chip = UIColor { $0.userInterfaceStyle == .dark ? hex(0x2F5D93) : hex(0xD3E5FF) }
    static let scrim = UIColor { $0.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.55) : UIColor.black.withAlphaComponent(0.28) }

    private static func hex(_ value: Int) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1)
    }
}
