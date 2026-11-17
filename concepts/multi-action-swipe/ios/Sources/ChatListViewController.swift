import UIKit

final class ChatListViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var chats = ChatPreview.mock
    private var configuration = ActionConfigurationStore.load()
    private weak var openCell: SwipeActionCell?
    private var undoPayload: (chat: ChatPreview, index: Int)?
    private var toastWorkItem: DispatchWorkItem?
    private var toastView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chats"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Customize",
            image: UIImage(systemName: "slider.horizontal.3"),
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
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 88))
        header.backgroundColor = Palette.canvas

        let eyebrow = UILabel()
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        eyebrow.text = "INTERACTION LAB  ·  MOCK DATA"
        eyebrow.font = .roundedPreferredFont(forTextStyle: .caption1, weight: .bold)
        eyebrow.adjustsFontForContentSizeCategory = true
        eyebrow.textColor = Palette.accent

        let instruction = UILabel()
        instruction.translatesAutoresizingMaskIntoConstraints = false
        instruction.text = "Swipe a chat left or right to reveal three actions."
        instruction.font = .preferredFont(forTextStyle: .subheadline)
        instruction.adjustsFontForContentSizeCategory = true
        instruction.textColor = Palette.secondaryText
        instruction.numberOfLines = 0

        header.addSubview(eyebrow)
        header.addSubview(instruction)
        NSLayoutConstraint.activate([
            eyebrow.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Metrics.horizontalInset),
            eyebrow.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -Metrics.horizontalInset),
            eyebrow.topAnchor.constraint(equalTo: header.topAnchor, constant: 14),
            instruction.leadingAnchor.constraint(equalTo: eyebrow.leadingAnchor),
            instruction.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -Metrics.horizontalInset),
            instruction.topAnchor.constraint(equalTo: eyebrow.bottomAnchor, constant: 7),
            instruction.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -12)
        ])
        return header
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
            chats[indexPath.row].unreadCount = 0
            reload(row: indexPath.row, announcement: "Marked \(chats[indexPath.row].name) as read")

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

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        closeOpenCell()
    }
}

extension ChatListViewController: SwipeActionCellDelegate {
    func swipeCellDidBeginInteraction(_ cell: SwipeActionCell) {
        closeOpenCell(except: cell)
        openCell = cell
    }

    func swipeCell(_ cell: SwipeActionCell, didRequest action: ChatAction) {
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
        UIAccessibility.post(notification: .announcement, argument: "Swipe actions updated")
    }
}
