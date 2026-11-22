import UIKit

@MainActor protocol MessageCellDelegate: AnyObject {
    func messageCellDidTapReaction(_ cell: MessageCell)
    func messageCellDidRequestPicker(_ cell: MessageCell)
}

final class MessageCell: UITableViewCell {
    static let reuseID = "MessageCell"
    weak var delegate: MessageCellDelegate?
    private let bubble = UIView()
    private let senderLabel = UILabel()
    private let bodyLabel = UILabel()
    private let timeLabel = UILabel()
    private let chip = UIButton(type: .system)
    private var leading: NSLayoutConstraint!
    private var trailing: NSLayoutConstraint!
    private var chipLeading: NSLayoutConstraint!
    private var chipTrailing: NSLayoutConstraint!
    private var model: Message?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(bubble)
        [senderLabel, bodyLabel, timeLabel].forEach { bubble.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(chip)
        bubble.translatesAutoresizingMaskIntoConstraints = false
        chip.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 18
        bubble.layer.cornerCurve = .continuous
        senderLabel.font = .preferredFont(forTextStyle: .caption1)
        senderLabel.textColor = Palette.accent
        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.textColor = Palette.primary
        bodyLabel.numberOfLines = 0
        timeLabel.font = .preferredFont(forTextStyle: .caption2)
        timeLabel.textColor = Palette.secondary
        chip.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        chip.backgroundColor = Palette.chip
        chip.layer.cornerRadius = 14
        chip.layer.borderWidth = 1
        chip.layer.borderColor = Palette.accent.cgColor
        chip.contentEdgeInsets = UIEdgeInsets(top: 5, left: 9, bottom: 5, right: 9)
        chip.addTarget(self, action: #selector(chipTapped), for: .touchUpInside)
        chip.addTarget(self, action: #selector(chipDown), for: .touchDown)
        chip.addTarget(self, action: #selector(chipUp), for: [.touchCancel, .touchDragExit, .touchUpInside])
        leading = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailing = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        chipLeading = chip.leadingAnchor.constraint(equalTo: bubble.leadingAnchor)
        chipTrailing = chip.trailingAnchor.constraint(equalTo: bubble.trailingAnchor)
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.78),
            senderLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8), senderLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12), senderLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 2), bodyLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12), bodyLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            timeLabel.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 3), timeLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12), timeLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
            chip.topAnchor.constraint(equalTo: bubble.bottomAnchor, constant: 4), chip.heightAnchor.constraint(greaterThanOrEqualToConstant: 28), chip.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ message: Message) {
        model = message
        senderLabel.text = message.sender
        bodyLabel.text = message.text
        timeLabel.text = message.time
        bubble.backgroundColor = message.outgoing ? Palette.bubbleOut : Palette.bubbleIn
        leading.isActive = !message.outgoing; trailing.isActive = message.outgoing
        chipLeading.isActive = !message.outgoing; chipTrailing.isActive = message.outgoing
        if let index = message.reactionIndex {
            chip.isHidden = false
            chip.setTitle("\(reactions[index].glyph)  1", for: .normal)
            chip.accessibilityLabel = String(format: NSLocalizedString("a11y.yourReaction", comment: ""), reactions[index].name)
            chip.accessibilityHint = String(format: NSLocalizedString("a11y.removeReactionNamed", comment: ""), reactions[index].name)
            chip.accessibilityIdentifier = "chat.chip.\(message.id)"
        } else { chip.isHidden = true }
        bubble.accessibilityIdentifier = "chat.message.\(message.id)"
        bubble.isAccessibilityElement = true
        bubble.accessibilityLabel = "\(message.sender), \(NSLocalizedString("a11y.message", comment: "")), \(message.text), \(message.time)"
        bubble.accessibilityValue = message.reactionIndex.map { String(format: NSLocalizedString("a11y.yourReaction", comment: ""), reactions[$0].name) } ?? NSLocalizedString("a11y.noReaction", comment: "")
        var actions = [UIAccessibilityCustomAction(name: NSLocalizedString("a11y.react", comment: ""), target: self, selector: #selector(requestPicker(_:)))]
        if message.reactionIndex != nil { actions.append(UIAccessibilityCustomAction(name: NSLocalizedString("a11y.removeReaction", comment: ""), target: self, selector: #selector(removeFromAccessibility(_:)))) }
        bubble.accessibilityCustomActions = actions
    }

    var bubbleView: UIView { bubble }
    var message: Message? { model }
    func setLifted(_ lifted: Bool, animated: Bool = true) {
        let changes = { self.bubble.transform = lifted ? .identity : CGAffineTransform(scaleX: 0.98, y: 0.98) }
        animated ? UIView.animate(withDuration: 0.12, animations: changes) : changes()
    }
    @objc private func chipTapped() { delegate?.messageCellDidTapReaction(self) }
    @objc private func requestPicker(_ action: UIAccessibilityCustomAction) -> Bool { delegate?.messageCellDidRequestPicker(self); return true }
    @objc private func removeFromAccessibility(_ action: UIAccessibilityCustomAction) -> Bool { delegate?.messageCellDidTapReaction(self); return true }
    @objc private func chipDown() { UIView.animate(withDuration: 0.08) { self.chip.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) } }
    @objc private func chipUp() { UIView.animate(withDuration: 0.08) { self.chip.transform = .identity } }
}
