import UIKit

protocol SwipeActionCellDelegate: AnyObject {
    func swipeCellDidBeginInteraction(_ cell: SwipeActionCell)
    func swipeCell(_ cell: SwipeActionCell, didRequest action: ChatAction)
}

final class SwipeActionCell: UITableViewCell {
    enum InteractionState: Equatable {
        case idle
        case touchDown
        case dragging(SwipeSide)
        case settling(SwipeSide?)
        case open(SwipeSide)
        case completing(ChatAction)
        case cancelled
    }

    static let reuseIdentifier = "SwipeActionCell"

    weak var delegate: SwipeActionCellDelegate?
    private(set) var interactionState: InteractionState = .idle

    private let actionHostView = UIView()
    private let leadingActions = UIStackView()
    private let trailingActions = UIStackView()
    private let surfaceView = UIView()
    private let avatarView = UIView()
    private let initialsLabel = UILabel()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadLabel = UILabel()
    private let statusStack = UIStackView()
    private let pinnedImageView = UIImageView()
    private let mutedImageView = UIImageView()
    private let favoriteImageView = UIImageView()
    private let dividerView = UIView()

    private var leading: [ChatAction] = []
    private var trailing: [ChatAction] = []
    private var currentOffset: CGFloat = 0
    private var panStartOffset: CGFloat = 0
    private var lastCrossedSlot = 0
    private var animator: UIViewPropertyAnimator?
    private var leadingWidthConstraint: NSLayoutConstraint!
    private var trailingWidthConstraint: NSLayoutConstraint!
    private var panGesture: UIPanGestureRecognizer!
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private var chat: ChatPreview?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildViewHierarchy()
        configureLayout()
        configureGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        animator?.stopAnimation(true)
        animator = nil
        currentOffset = 0
        surfaceView.transform = .identity
        interactionState = .idle
        lastCrossedSlot = 0
        leadingActions.arrangedSubviews.forEach { $0.transform = .identity }
        trailingActions.arrangedSubviews.forEach { $0.transform = .identity }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarView.layer.cornerRadius = avatarView.bounds.height / 2
        unreadLabel.layer.cornerRadius = unreadLabel.bounds.height / 2
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        guard currentOffset == 0 else { return }
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            interactionState = .touchDown
            impactFeedback.prepare()
        } else if interactionState == .touchDown {
            interactionState = .idle
        }
    }

    func configure(chat: ChatPreview, configuration: ActionConfiguration) {
        self.chat = chat
        titleLabel.text = chat.name
        messageLabel.text = chat.message
        timeLabel.text = chat.time
        initialsLabel.text = chat.initials
        avatarView.backgroundColor = chat.avatarColor

        unreadLabel.text = chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
        unreadLabel.isHidden = chat.unreadCount == 0
        pinnedImageView.isHidden = !chat.isPinned
        mutedImageView.isHidden = !chat.isMuted
        favoriteImageView.isHidden = !chat.isFavorite
        titleLabel.font = .roundedPreferredFont(
            forTextStyle: .body,
            weight: chat.unreadCount > 0 ? .semibold : .medium
        )
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = chat.unreadCount > 0 ? .label : Palette.secondaryText

        leading = configuration.leading
        trailing = configuration.trailing
        rebuildActions()
        updateAccessibility()
    }

    func close(animated: Bool = true) {
        settle(to: 0, side: nil, animated: animated)
    }

    private func buildViewHierarchy() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        clipsToBounds = true

        [actionHostView, surfaceView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        actionHostView.backgroundColor = Palette.canvas
        surfaceView.backgroundColor = .systemBackground

        [leadingActions, trailingActions].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.axis = .horizontal
            $0.distribution = .fillEqually
            $0.spacing = 0
            actionHostView.addSubview($0)
        }

        [avatarView, titleLabel, messageLabel, timeLabel, unreadLabel, statusStack, dividerView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surfaceView.addSubview($0)
        }

        statusStack.axis = .horizontal
        statusStack.alignment = .center
        statusStack.spacing = 4
        [pinnedImageView, favoriteImageView, mutedImageView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            statusStack.addArrangedSubview($0)
        }

        avatarView.addSubview(initialsLabel)
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.textAlignment = .center
        initialsLabel.textColor = .white
        initialsLabel.font = .roundedPreferredFont(forTextStyle: .headline, weight: .semibold)
        initialsLabel.adjustsFontForContentSizeCategory = true
        initialsLabel.pinEdges(to: avatarView)

        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byTruncatingTail
        timeLabel.font = .preferredFont(forTextStyle: .caption1)
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = Palette.secondaryText
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        unreadLabel.font = .roundedPreferredFont(forTextStyle: .caption2, weight: .bold)
        unreadLabel.adjustsFontForContentSizeCategory = true
        unreadLabel.textColor = .white
        unreadLabel.backgroundColor = Palette.accent
        unreadLabel.textAlignment = .center
        unreadLabel.clipsToBounds = true
        unreadLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        configureStatusIcon(pinnedImageView, symbol: "pin.fill", color: Palette.orange)
        configureStatusIcon(mutedImageView, symbol: "speaker.slash.fill", color: Palette.secondaryText)
        configureStatusIcon(favoriteImageView, symbol: "star.fill", color: Palette.gold)
        dividerView.backgroundColor = Palette.divider

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    private func configureStatusIcon(_ imageView: UIImageView, symbol: String, color: UIColor) {
        imageView.image = UIImage(systemName: symbol)
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false
    }

    private func configureLayout() {
        leadingWidthConstraint = leadingActions.widthAnchor.constraint(equalToConstant: 0)
        trailingWidthConstraint = trailingActions.widthAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            actionHostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionHostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionHostView.topAnchor.constraint(equalTo: contentView.topAnchor),
            actionHostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            surfaceView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: contentView.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            surfaceView.heightAnchor.constraint(greaterThanOrEqualToConstant: Metrics.minimumRowHeight),

            leadingActions.leadingAnchor.constraint(equalTo: actionHostView.leadingAnchor),
            leadingActions.topAnchor.constraint(equalTo: actionHostView.topAnchor),
            leadingActions.bottomAnchor.constraint(equalTo: actionHostView.bottomAnchor),
            leadingWidthConstraint,

            trailingActions.trailingAnchor.constraint(equalTo: actionHostView.trailingAnchor),
            trailingActions.topAnchor.constraint(equalTo: actionHostView.topAnchor),
            trailingActions.bottomAnchor.constraint(equalTo: actionHostView.bottomAnchor),
            trailingWidthConstraint,

            avatarView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: Metrics.horizontalInset),
            avatarView.topAnchor.constraint(greaterThanOrEqualTo: surfaceView.topAnchor, constant: 12),
            avatarView.centerYAnchor.constraint(equalTo: surfaceView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 50),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            timeLabel.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -Metrics.horizontalInset),

            titleLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: 11),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -Metrics.compactSpacing),

            statusStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),

            pinnedImageView.widthAnchor.constraint(equalToConstant: 14),
            pinnedImageView.heightAnchor.constraint(equalToConstant: 14),

            favoriteImageView.widthAnchor.constraint(equalToConstant: 14),
            favoriteImageView.heightAnchor.constraint(equalToConstant: 14),

            mutedImageView.widthAnchor.constraint(equalToConstant: 14),
            mutedImageView.heightAnchor.constraint(equalToConstant: 14),

            messageLabel.leadingAnchor.constraint(equalTo: statusStack.trailingAnchor, constant: 6),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: unreadLabel.leadingAnchor, constant: -Metrics.compactSpacing),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: surfaceView.bottomAnchor, constant: -12),

            unreadLabel.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -Metrics.horizontalInset),
            unreadLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 7),
            unreadLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            unreadLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),

            dividerView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            dividerView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    private func configureGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y) * 1.15
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            interruptAnimatorAtPresentationPosition()
            panStartOffset = currentOffset
            lastCrossedSlot = Int(abs(currentOffset) / Metrics.actionWidth)
            selectionFeedback.prepare()
            impactFeedback.prepare()
            delegate?.swipeCellDidBeginInteraction(self)

        case .changed:
            let raw = panStartOffset + gesture.translation(in: self).x
            let limited = rubberBand(raw)
            let side: SwipeSide = limited >= 0 ? .leading : .trailing
            interactionState = .dragging(side)
            apply(offset: limited)
            updateThresholdFeedback(for: limited, side: side)

        case .ended:
            let velocity = gesture.velocity(in: self).x
            let projected = currentOffset + velocity * 0.16
            let side: SwipeSide? = projected > Metrics.actionWidth * 0.55
                ? .leading
                : projected < -Metrics.actionWidth * 0.55 ? .trailing : nil
            let target = side.map { openOffset(for: $0) } ?? 0
            settle(to: target, side: side, animated: true)

        case .cancelled, .failed:
            interactionState = .cancelled
            settle(to: 0, side: nil, animated: true)

        default:
            break
        }
    }

    private func rubberBand(_ value: CGFloat) -> CGFloat {
        let side: SwipeSide = value >= 0 ? .leading : .trailing
        let maxValue = abs(openOffset(for: side))
        let magnitude = abs(value)
        guard magnitude > maxValue else { return value }
        let overflow = magnitude - maxValue
        let resisted = maxValue + (overflow * 0.22)
        return value >= 0 ? resisted : -resisted
    }

    private func openOffset(for side: SwipeSide) -> CGFloat {
        let count = CGFloat(side == .leading ? leading.count : trailing.count)
        return (side == .leading ? 1 : -1) * Metrics.actionWidth * count
    }

    private func apply(offset: CGFloat) {
        currentOffset = offset
        surfaceView.transform = CGAffineTransform(translationX: offset, y: 0)
        leadingActions.alpha = offset > 0 ? 1 : 0
        trailingActions.alpha = offset < 0 ? 1 : 0
    }

    private func updateThresholdFeedback(for offset: CGFloat, side: SwipeSide) {
        let actions = side == .leading ? leading : trailing
        let slot = min(actions.count, Int(abs(offset) / Metrics.actionWidth) + (abs(offset) > 12 ? 1 : 0))
        if slot != lastCrossedSlot {
            selectionFeedback.selectionChanged()
            selectionFeedback.prepare()
            lastCrossedSlot = slot
        }

        let stack = side == .leading ? leadingActions : trailingActions
        for (index, view) in stack.arrangedSubviews.enumerated() {
            let active = index == max(0, slot - 1) && abs(offset) > 12
            view.transform = active ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }
    }

    private func settle(to target: CGFloat, side: SwipeSide?, animated: Bool) {
        interruptAnimatorAtPresentationPosition()
        interactionState = .settling(side)

        let animations = { [weak self] in
            guard let self else { return }
            self.surfaceView.transform = CGAffineTransform(translationX: target, y: 0)
            self.leadingActions.alpha = target > 0 ? 1 : 0
            self.trailingActions.alpha = target < 0 ? 1 : 0
            self.leadingActions.arrangedSubviews.forEach { $0.transform = .identity }
            self.trailingActions.arrangedSubviews.forEach { $0.transform = .identity }
        }

        guard animated else {
            apply(offset: target)
            leadingActions.arrangedSubviews.forEach { $0.transform = .identity }
            trailingActions.arrangedSubviews.forEach { $0.transform = .identity }
            interactionState = side.map(InteractionState.open) ?? .idle
            return
        }

        let animator: UIViewPropertyAnimator
        if UIAccessibility.isReduceMotionEnabled {
            animator = UIViewPropertyAnimator(duration: 0.16, curve: .easeOut, animations: animations)
        } else {
            animator = UIViewPropertyAnimator(duration: 0.48, dampingRatio: 0.78, animations: animations)
        }
        animator.addCompletion { [weak self] position in
            guard let self, position == .end else { return }
            self.currentOffset = target
            self.interactionState = side.map(InteractionState.open) ?? .idle
            if side != nil {
                self.impactFeedback.impactOccurred(intensity: 0.65)
            }
            self.animator = nil
        }
        self.animator = animator
        animator.startAnimation()
    }

    private func interruptAnimatorAtPresentationPosition() {
        guard let animator else { return }
        let visibleOffset = surfaceView.layer.presentation()?.affineTransform().tx ?? currentOffset
        animator.stopAnimation(true)
        self.animator = nil
        apply(offset: visibleOffset)
    }

    private func rebuildActions() {
        [leadingActions, trailingActions].forEach { stack in
            stack.arrangedSubviews.forEach {
                stack.removeArrangedSubview($0)
                $0.removeFromSuperview()
            }
        }

        leading.forEach { leadingActions.addArrangedSubview(makeActionButton(for: $0)) }
        trailing.forEach { trailingActions.addArrangedSubview(makeActionButton(for: $0)) }
        leadingWidthConstraint.constant = CGFloat(leading.count) * Metrics.actionWidth
        trailingWidthConstraint.constant = CGFloat(trailing.count) * Metrics.actionWidth
    }

    private func makeActionButton(for action: ChatAction) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = action.tintColor
        configuration.baseForegroundColor = .white
        configuration.image = UIImage(systemName: action.symbolName)
        configuration.imagePlacement = .top
        configuration.imagePadding = 5
        configuration.title = action.shortTitle
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .roundedPreferredFont(forTextStyle: .caption2, weight: .semibold)
            return outgoing
        }
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = 0
        button.configuration = configuration
        button.accessibilityLabel = action.title
        button.accessibilityHint = action.isDestructive ? "Requires confirmation" : "Performs this action on the chat"
        button.addAction(UIAction { [weak self] _ in
            self?.request(action)
        }, for: .touchUpInside)
        return button
    }

    private func request(_ action: ChatAction) {
        interactionState = .completing(action)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(action.isDestructive ? .warning : .success)
        delegate?.swipeCell(self, didRequest: action)
        if !action.isDestructive {
            close(animated: true)
        }
    }

    private func updateAccessibility() {
        guard let chat else { return }
        var status: [String] = []
        if chat.unreadCount > 0 { status.append("\(chat.unreadCount) unread") }
        if chat.isPinned { status.append("Pinned") }
        if chat.isMuted { status.append("Muted") }
        if chat.isFavorite { status.append("Favorite") }

        accessibilityLabel = [chat.name, chat.message, chat.time, status.joined(separator: ", ")]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        accessibilityHint = "Double tap to open. Use the Actions rotor, or swipe horizontally, for chat actions."
        accessibilityCustomActions = (leading + trailing).uniqued().map { action in
            UIAccessibilityCustomAction(name: action.title) { [weak self] _ in
                self?.request(action)
                return true
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
