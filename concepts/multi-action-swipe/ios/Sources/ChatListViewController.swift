import UIKit

final class ChatListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var chats = ChatPreview.mock
    private var configuration = ActionConfigurationStore.load()
    private weak var openCell: SwipeActionCell?
    private var undoPayload: (chat: ChatPreview, index: Int)?
    private var toastWorkItem: DispatchWorkItem?
    private var toastView: UIView?
    private var demoCloseWorkItem: DispatchWorkItem?
    private var coachMarkVisible = !UserDefaults.standard.bool(forKey: "multiActionSwipe.coachMarkDismissed.v2")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chats"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Replay Demo",
            style: .plain,
            target: self,
            action: #selector(replayDemo)
        )
        navigationItem.leftBarButtonItem?.accessibilityHint = "Shows the swipe hint and opens the first action tray"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Settings",
            style: .plain,
            target: self,
            action: #selector(showConfiguration)
        )
        navigationItem.rightBarButtonItem?.accessibilityHint = "Choose which actions appear on each side"
        view.backgroundColor = Palette.canvas
        configureTable()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let targetSize = CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let height = header.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        guard abs(header.frame.height - height) > 0.5 else { return }
        header.frame.size.height = height
        tableView.tableHeaderView = header
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = Metrics.minimumRowHeight
        tableView.register(SwipeActionCell.self, forCellReuseIdentifier: SwipeActionCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.tableHeaderView = makeHeader()
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 80))
        header.backgroundColor = Palette.canvas

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        header.addSubview(stack)

        let eyebrow = UILabel()
        eyebrow.text = "MOCK DATA — not connected to Telegram"
        eyebrow.font = .roundedPreferredFont(forTextStyle: .caption1, weight: .bold)
        eyebrow.adjustsFontForContentSizeCategory = true
        eyebrow.textColor = Palette.accent
        eyebrow.numberOfLines = 0
        stack.addArrangedSubview(eyebrow)

        if coachMarkVisible {
            stack.addArrangedSubview(makeCoachMark())
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Metrics.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Metrics.horizontalInset),
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12)
        ])
        return header
    }

    private func makeCoachMark() -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.cornerCurve = .continuous

        let content = UIStackView()
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 10
        card.addSubview(content)

        let titleRow = UIStackView()
        titleRow.axis = .horizontal
        titleRow.alignment = .center

        let title = UILabel()
        title.text = "Swipe left for actions"
        title.font = .roundedPreferredFont(forTextStyle: .headline, weight: .semibold)
        title.adjustsFontForContentSizeCategory = true
        titleRow.addArrangedSubview(title)

        let dismiss = UIButton(type: .close)
        dismiss.accessibilityLabel = "Dismiss swipe hint"
        dismiss.addTarget(self, action: #selector(dismissCoachMark), for: .touchUpInside)
        dismiss.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        dismiss.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        titleRow.addArrangedSubview(dismiss)
        content.addArrangedSubview(titleRow)

        let preview = UIStackView()
        preview.axis = .horizontal
        preview.distribution = .fillEqually
        preview.spacing = 4
        for action in ActionConfiguration.defaults.trailing {
            let item = UILabel()
            item.text = "  \(action.shortTitle)"
            item.font = .roundedPreferredFont(forTextStyle: .caption2, weight: .semibold)
            item.textColor = .white
            item.backgroundColor = action.tintColor
            item.textAlignment = .center
            item.layer.cornerRadius = 8
            item.clipsToBounds = true
            item.heightAnchor.constraint(equalToConstant: 32).isActive = true
            item.isAccessibilityElement = false
            preview.addArrangedSubview(item)
        }
        preview.accessibilityLabel = "Preview: Archive, Mute, Delete action tray"
        preview.isAccessibilityElement = true
        content.addArrangedSubview(preview)

        let detail = UILabel()
        detail.text = "Reveal Archive, Mute, and Delete without performing an action."
        detail.font = .preferredFont(forTextStyle: .footnote)
        detail.adjustsFontForContentSizeCategory = true
        detail.textColor = Palette.secondaryText
        detail.numberOfLines = 0
        content.addArrangedSubview(detail)

        var tryConfiguration = UIButton.Configuration.tinted()
        tryConfiguration.title = "Try Demo"
        tryConfiguration.image = UIImage(systemName: "hand.tap.fill")
        tryConfiguration.imagePadding = 8
        tryConfiguration.cornerStyle = .medium
        let tryButton = UIButton(configuration: tryConfiguration)
        tryButton.titleLabel?.font = .roundedPreferredFont(forTextStyle: .body, weight: .semibold)
        tryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        tryButton.accessibilityHint = "Opens and then closes the first chat's action tray without performing an action"
        tryButton.addTarget(self, action: #selector(tryDemo), for: .touchUpInside)
        content.addArrangedSubview(tryButton)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func refreshHeader() {
        tableView.tableHeaderView = makeHeader()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    @objc private func dismissCoachMark() {
        coachMarkVisible = false
        UserDefaults.standard.set(true, forKey: "multiActionSwipe.coachMarkDismissed.v2")
        refreshHeader()
    }

    @objc private func replayDemo() {
        coachMarkVisible = true
        refreshHeader()
        DispatchQueue.main.async { [weak self] in self?.tryDemo() }
    }

    @objc private func tryDemo() {
        guard !chats.isEmpty else { return }
        demoCloseWorkItem?.cancel()
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .none, animated: false)
        tableView.layoutIfNeeded()
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? SwipeActionCell else { return }
        closeOpenCell(except: cell)
        cell.open(.trailing, animated: true)
        UIAccessibility.post(notification: .announcement, argument: "Action tray opened for \(chats[0].name). No action selected.")

        let item = DispatchWorkItem { [weak self, weak cell] in
            cell?.close(animated: true)
            if self?.openCell === cell { self?.openCell = nil }
        }
        demoCloseWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: item)
    }

    @objc private func showConfiguration() {
        closeOpenCell()
        let controller = ActionConfigurationViewController(configuration: configuration)
        controller.delegate = self
        let navigation = UINavigationController(rootViewController: controller)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
        }
        present(navigation, animated: true)
    }

    private func closeOpenCell(except cell: SwipeActionCell? = nil) {
        guard let openCell, openCell !== cell else { return }
        openCell.close(animated: true)
        self.openCell = nil
    }

    private func handle(action: ChatAction, for cell: SwipeActionCell) {
        guard let indexPath = tableView.indexPath(for: cell), chats.indices.contains(indexPath.row) else { return }
        switch action {
        case .read:
            let wasUnread = chats[indexPath.row].unreadCount > 0
            chats[indexPath.row].unreadCount = wasUnread ? 0 : 1
            reload(
                row: indexPath.row,
                announcement: "Marked \(chats[indexPath.row].name) as \(wasUnread ? "read" : "unread")"
            )

        case .pin:
            chats[indexPath.row].isPinned.toggle()
            let state = chats[indexPath.row].isPinned ? "Pinned" : "Unpinned"
            reload(row: indexPath.row, announcement: "\(state) \(chats[indexPath.row].name)")

        case .mute:
            chats[indexPath.row].isMuted.toggle()
            let state = chats[indexPath.row].isMuted ? "Muted" : "Unmuted"
            reload(row: indexPath.row, announcement: "\(state) \(chats[indexPath.row].name)")

        case .favorite:
            chats[indexPath.row].isFavorite.toggle()
            let state = chats[indexPath.row].isFavorite ? "Added to favorites" : "Removed from favorites"
            reload(row: indexPath.row, announcement: "\(state): \(chats[indexPath.row].name)")

        case .archive:
            removeChat(at: indexPath.row, verb: "Archived")

        case .delete:
            confirmDelete(at: indexPath.row, cell: cell)
        }
    }

    private func reload(row: Int, announcement: String) {
        openCell = nil
        tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        showToast(message: announcement, offersUndo: false)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func confirmDelete(at index: Int, cell: SwipeActionCell) {
        let chat = chats[index]
        let alert = UIAlertController(
            title: "Delete mock chat?",
            message: "This removes \(chat.name) from the demo list. You can undo immediately afterward.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            cell.close(animated: true)
        })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.removeChat(at: index, verb: "Deleted")
        })
        present(alert, animated: true)
    }

    private func removeChat(at index: Int, verb: String) {
        guard chats.indices.contains(index) else { return }
        let removed = chats.remove(at: index)
        undoPayload = (removed, index)
        openCell = nil
        tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: UIAccessibility.isReduceMotionEnabled ? .none : .automatic)
        showToast(message: "\(verb) \(removed.name)", offersUndo: true)
        UIAccessibility.post(notification: .announcement, argument: "\(verb) \(removed.name). Undo available.")
    }

    private func showToast(message: String, offersUndo: Bool) {
        toastWorkItem?.cancel()
        toastView?.removeFromSuperview()

        let toast = UIView()
        toast.translatesAutoresizingMaskIntoConstraints = false
        toast.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.92, alpha: 0.98)
                : UIColor(white: 0.12, alpha: 0.96)
        }
        toast.layer.cornerRadius = 14
        toast.layer.cornerCurve = .continuous
        toast.accessibilityViewIsModal = false

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textColor = UIColor { traits in traits.userInterfaceStyle == .dark ? .black : .white }
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        toast.addSubview(label)

        var trailingAnchor = label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -16)
        if offersUndo {
            let undo = UIButton(type: .system)
            undo.translatesAutoresizingMaskIntoConstraints = false
            undo.setTitle("Undo", for: .normal)
            undo.titleLabel?.font = .roundedPreferredFont(forTextStyle: .subheadline, weight: .bold)
            undo.tintColor = Palette.accent
            undo.accessibilityHint = "Restores the removed mock chat"
            undo.addTarget(self, action: #selector(undoRemoval), for: .touchUpInside)
            toast.addSubview(undo)
            trailingAnchor = label.trailingAnchor.constraint(lessThanOrEqualTo: undo.leadingAnchor, constant: -12)
            NSLayoutConstraint.activate([
                undo.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -10),
                undo.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
                undo.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
                undo.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
            ])
        }

        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 16),
            label.topAnchor.constraint(greaterThanOrEqualTo: toast.topAnchor, constant: 10),
            label.bottomAnchor.constraint(lessThanOrEqualTo: toast.bottomAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: toast.centerYAnchor),
            trailingAnchor
        ])

        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 12)
        let show = {
            toast.alpha = 1
            toast.transform = .identity
        }
        if UIAccessibility.isReduceMotionEnabled {
            show()
        } else {
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: show)
        }
        toastView = toast

        let item = DispatchWorkItem { [weak self, weak toast] in
            guard let toast else { return }
            let remove = {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 8)
            }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.16, animations: remove) { _ in
                toast.removeFromSuperview()
                if self?.toastView === toast { self?.toastView = nil }
            }
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + (offersUndo ? 5.0 : 3.0), execute: item)
    }

    @objc private func undoRemoval() {
        guard let payload = undoPayload else { return }
        let insertionIndex = min(payload.index, chats.count)
        chats.insert(payload.chat, at: insertionIndex)
        tableView.insertRows(at: [IndexPath(row: insertionIndex, section: 0)], with: UIAccessibility.isReduceMotionEnabled ? .none : .automatic)
        undoPayload = nil
        toastWorkItem?.cancel()
        toastView?.removeFromSuperview()
        toastView = nil
        UIAccessibility.post(notification: .announcement, argument: "Restored \(payload.chat.name)")
    }
}

extension ChatListViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        chats.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: SwipeActionCell.reuseIdentifier,
            for: indexPath
        ) as? SwipeActionCell else {
            return UITableViewCell()
        }
        cell.delegate = self
        cell.configure(chat: chats[indexPath.row], configuration: configuration)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        closeOpenCell()
        tableView.deselectRow(at: indexPath, animated: true)
        showToast(message: "Demo only · no chat backend", offersUndo: false)
    }

    func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard chats.indices.contains(indexPath.row) else { return nil }
        let chatID = chats[indexPath.row].id
        return UIContextMenuConfiguration(identifier: chatID.uuidString as NSString, previewProvider: nil) { [weak self] _ in
            guard
                let self,
                let currentIndex = self.chats.firstIndex(where: { $0.id == chatID }),
                let cell = tableView.cellForRow(at: IndexPath(row: currentIndex, section: 0)) as? SwipeActionCell
            else { return nil }

            var seen = Set<ChatAction>()
            let actions = (self.configuration.leading + self.configuration.trailing).filter { seen.insert($0).inserted }
            return UIMenu(title: "Chat actions", children: actions.map { action in
                UIAction(
                    title: action.title(for: self.chats[currentIndex]),
                    image: UIImage(systemName: action.symbolName),
                    attributes: action.isDestructive ? .destructive : []
                ) { [weak self, weak cell] _ in
                    guard let self, let cell else { return }
                    self.handle(action: action, for: cell)
                }
            })
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        demoCloseWorkItem?.cancel()
        closeOpenCell()
    }
}

extension ChatListViewController: SwipeActionCellDelegate {
    func swipeCellDidBeginInteraction(_ cell: SwipeActionCell) {
        closeOpenCell(except: cell)
        openCell = cell
    }

    func swipeCell(_ cell: SwipeActionCell, didRequest action: ChatAction) {
        demoCloseWorkItem?.cancel()
        handle(action: action, for: cell)
    }
}

extension ChatListViewController: ActionConfigurationViewControllerDelegate {
    func configurationViewController(
        _ controller: ActionConfigurationViewController,
        didSave configuration: ActionConfiguration
    ) {
        self.configuration = configuration
        openCell = nil
        tableView.reloadData()
        refreshHeader()
        UIAccessibility.post(notification: .announcement, argument: "Swipe actions updated")
    }
}
