import UIKit

enum Palette {
    static let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.70, blue: 1.00, alpha: 1)
            : UIColor(red: 0.10, green: 0.52, blue: 0.92, alpha: 1)
    }
    static let blue = UIColor.systemBlue
    static let indigo = UIColor.systemIndigo
    static let orange = UIColor.systemOrange
    static let destructive = UIColor.systemRed
    static let gold = UIColor.systemYellow
    static let mint = UIColor.systemMint
    static let coral = UIColor.systemPink
    static let purple = UIColor.systemPurple
    static let slate = UIColor.systemGray

    static let canvas = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.07, blue: 0.10, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1)
    }
    static let surface = UIColor.secondarySystemBackground
    static let divider = UIColor.separator
    static let secondaryText = UIColor.secondaryLabel
}
enum Metrics {
    static let actionWidth: CGFloat = 76
    static let minimumRowHeight: CGFloat = 82
    static let horizontalInset: CGFloat = 16
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 16
}

extension UIFont {
    static func roundedPreferredFont(forTextStyle style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: 0).withWeight(weight)
    }

    private func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let traits = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: traits, size: pointSize)
    }
}

extension UIView {
    func pinEdges(to view: UIView) {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topAnchor.constraint(equalTo: view.topAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
