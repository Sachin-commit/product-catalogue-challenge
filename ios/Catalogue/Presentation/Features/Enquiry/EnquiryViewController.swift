import UIKit

/// Binds `EnquiryFormView` to `EnquiryViewModel`: edits go to the model,
/// the model's state is rendered back. Navigation is the model's job.
final class EnquiryViewController: UIViewController {
    private let model: EnquiryViewModel
    private let imageLoader: any ImageLoading
    private let form = EnquiryFormView()

    init(model: EnquiryViewModel, imageLoader: any ImageLoading) {
        self.model = model
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = model.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func loadView() {
        view = form
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.model.cancel()
        })

        form.showProduct(model.product, imageLoader: imageLoader)
        form.onChange = { [weak self] field, text in self?.update(field, to: text) }
        form.onSubmit = { [weak self] in
            guard let model = self?.model else { return }
            Task { await model.submit() }
        }

        renderOnChange { [weak self] in self?.render() }
    }

    private func update(_ field: EnquiryField, to text: String) {
        switch field {
        case .name: model.name = text
        case .email: model.email = text
        case .phone: model.phone = text
        case .message: model.message = text
        }
        model.clearError(for: field)
    }

    private func render() {
        for field in EnquiryField.allCases {
            form.setError(model.fieldErrors[field], for: field)
        }
        form.setSubmitError(model.submitError)
        form.setSubmitting(model.isSubmitting, buttonTitle: model.sendButtonTitle)
        navigationItem.leftBarButtonItem?.isEnabled = !model.isSubmitting
        isModalInPresentation = !model.allowsInteractiveDismissal
    }
}

#Preview {
    UINavigationController(
        rootViewController: EnquiryViewController(
            model: EnquiryViewModel(
                product: PreviewData.products[0],
                submitEnquiry: PreviewData.submitEnquiry,
                navigator: nil
            ),
            imageLoader: PreviewData.imageLoader
        )
    )
}
