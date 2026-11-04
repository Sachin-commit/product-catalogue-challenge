import UIKit

/// The enquiry form's views and layout, and nothing else: no state, no rules.
/// `EnquiryViewController` binds it to `EnquiryViewModel`.
final class EnquiryFormView: UIView, UITextFieldDelegate, UITextViewDelegate {
    /// Called on every edit with the field and its new text.
    var onChange: ((EnquiryField, String) -> Void)?
    var onSubmit: (() -> Void)?

    private let productImage = ProductImageView()
    private let productTitle = UILabel(font: Theme.current.typography.productTitle, color: Theme.current.palette.textPrimary, lines: 2)
    private let productPrice = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.textSecondary)
    private let nameField = FormFieldView(placeholder: "Name")
    private let emailField = FormFieldView(placeholder: "Email")
    private let phoneField = FormFieldView(placeholder: "Phone (optional)")
    private let messageView = UITextView()
    private let messagePlaceholder = UILabel(font: Theme.current.typography.body, color: .placeholderText, lines: 0)
    private let messageError = FormFieldView.makeErrorLabel()
    private let submitErrorLabel = UILabel(font: Theme.current.typography.body, color: Theme.current.palette.error, lines: 0)
    private let sendButton = UIButton(configuration: .filled())
    private let scrollView = UIScrollView()

    init() {
        super.init(frame: .zero)
        let theme = Theme.current
        backgroundColor = theme.palette.background
        configureFields()
        configureMessage()

        var sendConfiguration = UIButton.Configuration.filled()
        sendConfiguration.cornerStyle = .large
        sendConfiguration.buttonSize = .large
        sendButton.configuration = sendConfiguration
        sendButton.tintColor = theme.palette.accent
        sendButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)
        submitErrorLabel.isHidden = true

        let stack = UIStackView(arrangedSubviews: [
            makeProductSummary(),
            sectionLabel("Your contact details"),
            nameField,
            emailField,
            phoneField,
            footnote("Our sales team will reply by email."),
            sectionLabel("Message (optional)"),
            messageView,
            messageError,
            submitErrorLabel,
            sendButton,
        ])
        stack.axis = .vertical
        stack.spacing = theme.spacing.m
        stack.setCustomSpacing(theme.spacing.xl, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(theme.spacing.xl, after: submitErrorLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        addSubview(scrollView)

        let inset = theme.spacing.l
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            // Keeps the focused field and the Send button above the keyboard.
            scrollView.bottomAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -inset),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -inset),
            messageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Rendering

    func showProduct(_ product: ProductCardModel, imageLoader: any ImageLoading) {
        productTitle.text = product.title
        productPrice.text = product.priceText
        productImage.load(product.imageURL, using: imageLoader)
    }

    func setError(_ message: String?, for field: EnquiryField) {
        switch field {
        case .name: nameField.setError(message)
        case .email: emailField.setError(message)
        case .phone: phoneField.setError(message)
        case .message:
            messageError.text = message
            messageError.isHidden = message == nil
        }
    }

    func setSubmitError(_ message: String?) {
        submitErrorLabel.text = message.map { "⚠︎ \($0)" }
        submitErrorLabel.isHidden = message == nil
    }

    func setSubmitting(_ isSubmitting: Bool, buttonTitle: String) {
        sendButton.configuration?.title = buttonTitle
        sendButton.configuration?.showsActivityIndicator = isSubmitting
        sendButton.isEnabled = !isSubmitting
    }

    // MARK: - Input

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameField.textField: emailField.textField.becomeFirstResponder()
        case emailField.textField: phoneField.textField.becomeFirstResponder()
        default: textField.resignFirstResponder()
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        messagePlaceholder.isHidden = !textView.text.isEmpty
        onChange?(.message, textView.text)
    }

    private func submit() {
        endEditing(true)
        onSubmit?()
    }

    // MARK: - Building

    private func configureFields() {
        nameField.textField.textContentType = .name
        nameField.textField.autocapitalizationType = .words
        nameField.textField.returnKeyType = .next

        emailField.textField.textContentType = .emailAddress
        emailField.textField.keyboardType = .emailAddress
        emailField.textField.autocapitalizationType = .none
        emailField.textField.autocorrectionType = .no
        emailField.textField.returnKeyType = .next

        phoneField.textField.textContentType = .telephoneNumber
        phoneField.textField.keyboardType = .phonePad

        let textFields: [(EnquiryField, FormFieldView)] = [(.name, nameField), (.email, emailField), (.phone, phoneField)]
        for (field, view) in textFields {
            view.textField.delegate = self
            view.textField.addAction(UIAction { [weak self, weak view] _ in
                self?.onChange?(field, view?.textField.text ?? "")
            }, for: .editingChanged)
        }
    }

    private func configureMessage() {
        let theme = Theme.current
        messageView.font = theme.typography.body
        messageView.adjustsFontForContentSizeCategory = true
        messageView.backgroundColor = theme.palette.surface
        messageView.layer.cornerRadius = theme.radius.m
        messageView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        messageView.isScrollEnabled = false
        messageView.delegate = self
        messageView.accessibilityLabel = "Message (optional)"

        messagePlaceholder.text = "Sizes, colours, delivery questions…"
        messagePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        messageView.addSubview(messagePlaceholder)
        NSLayoutConstraint.activate([
            messagePlaceholder.topAnchor.constraint(equalTo: messageView.topAnchor, constant: 12),
            messagePlaceholder.leadingAnchor.constraint(equalTo: messageView.leadingAnchor, constant: 13),
            messagePlaceholder.widthAnchor.constraint(equalTo: messageView.widthAnchor, constant: -26),
        ])
    }

    private func makeProductSummary() -> UIView {
        let theme = Theme.current
        let text = UIStackView(arrangedSubviews: [productTitle, productPrice])
        text.axis = .vertical
        text.spacing = theme.spacing.xs

        let row = UIStackView(arrangedSubviews: [productImage, text])
        row.spacing = theme.spacing.m
        row.alignment = .center
        NSLayoutConstraint.activate([
            productImage.widthAnchor.constraint(equalToConstant: 64),
            productImage.heightAnchor.constraint(equalToConstant: 64),
        ])
        return row
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel(font: Theme.current.typography.sectionTitle, color: Theme.current.palette.textPrimary)
        label.text = text
        label.accessibilityTraits = .header
        return label
    }

    private func footnote(_ text: String) -> UILabel {
        let label = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.textSecondary, lines: 0)
        label.text = text
        return label
    }
}

/// A text field with an inline validation message underneath.
final class FormFieldView: UIStackView {
    let textField = UITextField()
    private let errorLabel = FormFieldView.makeErrorLabel()

    init(placeholder: String) {
        super.init(frame: .zero)
        let theme = Theme.current
        axis = .vertical
        spacing = theme.spacing.xs

        textField.placeholder = placeholder
        textField.accessibilityLabel = placeholder
        textField.font = theme.typography.body
        textField.adjustsFontForContentSizeCategory = true
        textField.backgroundColor = theme.palette.surface
        textField.layer.cornerRadius = theme.radius.m
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true

        addArrangedSubview(textField)
        addArrangedSubview(errorLabel)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        textField.layer.borderWidth = message == nil ? 0 : 1
        textField.layer.borderColor = Theme.current.palette.error.cgColor
        textField.accessibilityValue = message.map { "Error: \($0)" }
    }

    static func makeErrorLabel() -> UILabel {
        let label = UILabel(font: Theme.current.typography.caption, color: Theme.current.palette.error, lines: 0)
        label.isHidden = true
        return label
    }
}
