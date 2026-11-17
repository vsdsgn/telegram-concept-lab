import UIKit

protocol ActionConfigurationViewControllerDelegate: AnyObject {
    func configurationViewController(
        _ controller: ActionConfigurationViewController,
        didSave configuration: ActionConfiguration
    )
}
final class ActionConfigurationViewController: UIViewController {
    weak var delegate: ActionConfigurationViewControllerDelegate?

    private var draft: ActionConfiguration
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var actionButtons: [String: UIButton] = [:]

    init(configuration: ActionConfiguration) {
        draft = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Customize actions"
        view.backgroundColor = Palette.canvas
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(save)
        )
        navigationItem.rightBarButtonItem?.accessibilityHint = "Saves the selected swipe actions"
        buildContent()
    }

    private func buildContent() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 16
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])

        let intro = UILabel()
        intro.text = "Choose the three actions revealed on each side. Changes are stored on this device for the next launch."
        intro.font = .preferredFont(forTextStyle: .body)
        intro.adjustsFontForContentSizeCategory = true
        intro.textColor = Palette.secondaryText
        intro.numberOfLines = 0
        contentStack.addArrangedSubview(intro)

        contentStack.addArrangedSubview(makeSection(side: .leading, title: "Swipe right", detail: "Actions appear from the leading edge."))
        contentStack.addArrangedSubview(makeSection(side: .trailing, title: "Swipe left", detail: "Actions appear from the trailing edge."))

        var resetConfiguration = UIButton.Configuration.gray()
        resetConfiguration.title = "Restore defaults"
        resetConfiguration.image = UIImage(systemName: "arrow.counterclockwise")
        resetConfiguration.imagePadding = 8
        resetConfiguration.cornerStyle = .medium
        let reset = UIButton(configuration: resetConfiguration)
        reset.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        reset.accessibilityHint = "Restores the default action order before saving"
        reset.addAction(UIAction { [weak self] _ in
            self?.draft = .defaults
            self?.refreshButtons()
            UISelectionFeedbackGenerator().selectionChanged()
        }, for: .touchUpInside)
        contentStack.addArrangedSubview(reset)
    }

    private func makeSection(side: SwipeSide, title: String, detail: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .roundedPreferredFont(forTextStyle: .headline, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        stack.addArrangedSubview(titleLabel)

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = Palette.secondaryText
        detailLabel.numberOfLines = 0
        stack.addArrangedSubview(detailLabel)

        for index in 0..<3 {
            let button = UIButton(type: .system)
            button.contentHorizontalAlignment = .leading
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            button.showsMenuAsPrimaryAction = true
            button.accessibilityHint = "Opens a menu of actions for slot \(index + 1)"
            actionButtons[key(side: side, index: index)] = button
            stack.addArrangedSubview(button)
            configure(button, side: side, index: index)
        }
        return card
    }

    private func configure(_ button: UIButton, side: SwipeSide, index: Int) {
        let selected = draft.actions(for: side)[index]
        var configuration = UIButton.Configuration.gray()
        configuration.title = "Slot \(index + 1)  ·  \(selected.title)"
        configuration.image = UIImage(systemName: selected.symbolName)
        configuration.imagePadding = 10
        configuration.baseForegroundColor = selected.tintColor
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        button.configuration = configuration
        button.accessibilityLabel = "Slot \(index + 1), \(selected.title)"
        button.menu = UIMenu(title: "Choose action", children: ChatAction.allCases.map { action in
            UIAction(
                title: action.title,
                image: UIImage(systemName: action.symbolName),
                state: action == selected ? .on : .off
            ) { [weak self] _ in
                self?.draft.set(action, side: side, index: index)
                self?.refreshButtons()
                UISelectionFeedbackGenerator().selectionChanged()
            }
        })
    }

    private func refreshButtons() {
        for side in [SwipeSide.leading, .trailing] {
            for index in 0..<3 {
                if let button = actionButtons[key(side: side, index: index)] {
                    configure(button, side: side, index: index)
                }
            }
        }
    }

    private func key(side: SwipeSide, index: Int) -> String {
        "\(side.rawValue)-\(index)"
    }

    @objc private func save() {
        ActionConfigurationStore.save(draft)
        delegate?.configurationViewController(self, didSave: draft)
        dismiss(animated: true)
    }
}
