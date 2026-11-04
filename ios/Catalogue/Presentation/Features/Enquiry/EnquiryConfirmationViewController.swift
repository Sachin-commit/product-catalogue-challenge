import UIKit

/// The "Thank you" screen, shown only after the backend confirms the email was accepted.
final class EnquiryConfirmationViewController: UIViewController {
    private let model: EnquiryConfirmationViewModel

    init(model: EnquiryConfirmationViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        navigationItem.hidesBackButton = true
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let theme = Theme.current
        view.backgroundColor = theme.palette.background

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = theme.palette.success
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64)
        icon.isAccessibilityElement = false

        let heading = UILabel(font: theme.typography.screenTitle, color: theme.palette.textPrimary)
        heading.text = model.heading
        heading.textAlignment = .center
        heading.accessibilityTraits = .header

        let body = UILabel(font: theme.typography.body, color: theme.palette.textSecondary, lines: 0)
        body.text = model.message
        body.textAlignment = .center

        let referenceLabel = UILabel(
            font: .monospacedSystemFont(ofSize: theme.typography.caption.pointSize, weight: .regular),
            color: theme.palette.textSecondary
        )
        referenceLabel.text = model.referenceText
        referenceLabel.textAlignment = .center

        var doneConfiguration = UIButton.Configuration.filled()
        doneConfiguration.title = model.doneTitle
        doneConfiguration.cornerStyle = .large
        doneConfiguration.buttonSize = .large
        let done = UIButton(configuration: doneConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.model.done()
        })
        done.tintColor = theme.palette.accent

        let message = UIStackView(arrangedSubviews: [icon, heading, body, referenceLabel])
        message.axis = .vertical
        message.alignment = .center
        message.spacing = theme.spacing.l
        message.translatesAutoresizingMaskIntoConstraints = false
        done.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(message)
        view.addSubview(done)

        let guide = view.safeAreaLayoutGuide
        let inset = theme.spacing.xl
        NSLayoutConstraint.activate([
            message.centerYAnchor.constraint(equalTo: guide.centerYAnchor, constant: -inset),
            message.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            message.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),
            done.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset),
            done.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset),
            done.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -theme.spacing.l),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Let VoiceOver users hear the confirmation straight away.
        UIAccessibility.post(notification: .screenChanged, argument: view.subviews.first)
    }
}
