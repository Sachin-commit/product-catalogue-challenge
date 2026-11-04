import UIKit

/// Search field with an explicit Search button: the acceptance criteria say
/// results appear when the customer *clicks the search button*.
/// A passive view: it reports text and taps; the view model decides what is searchable.
final class SearchBarView: UIView, UITextFieldDelegate {
    var onTextChange: ((String) -> Void)?
    var onSearch: (() -> Void)?

    private let textField = UITextField()
    private let searchButton = UIButton(configuration: .filled())

    init() {
        super.init(frame: .zero)
        let theme = Theme.current

        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = theme.palette.textSecondary
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 36, height: 20)

        textField.placeholder = "Search products"
        textField.font = theme.typography.body
        textField.adjustsFontForContentSizeCategory = true
        textField.backgroundColor = theme.palette.surface
        textField.layer.cornerRadius = theme.radius.m
        textField.leftView = icon
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.delegate = self
        textField.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            onTextChange?(textField.text ?? "")
        }, for: .editingChanged)

        searchButton.configuration?.title = "Search"
        searchButton.configuration?.cornerStyle = .medium
        searchButton.tintColor = theme.palette.accent
        searchButton.addAction(UIAction { [weak self] _ in self?.search() }, for: .touchUpInside)
        searchButton.setContentHuggingPriority(.required, for: .horizontal)
        searchButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        searchButton.isEnabled = false

        let stack = UIStackView(arrangedSubviews: [textField, searchButton])
        stack.spacing = theme.spacing.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setSearchEnabled(_ isEnabled: Bool) {
        searchButton.isEnabled = isEnabled
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        search()
        return true
    }

    private func search() {
        guard searchButton.isEnabled else { return }
        textField.resignFirstResponder()
        onSearch?()
    }
}
