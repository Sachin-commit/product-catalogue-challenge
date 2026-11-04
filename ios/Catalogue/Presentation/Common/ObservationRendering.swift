import Observation

/// Calls `render` now, and again whenever an `@Observable` property it read changes.
///
/// This is the binding between view controllers (views) and view models in our
/// MVVM: view models are plain `@Observable` classes with no UIKit in them, and a
/// view controller re-renders from its view model's state. (On iOS 18+ UIKit can
/// track observation automatically; this keeps iOS 17 support.)
///
/// Pass a closure that captures its view controller weakly: once the screen is
/// gone the closure reads nothing, so tracking stops by itself.
@MainActor
func renderOnChange(_ render: @escaping @MainActor @Sendable () -> Void) {
    withObservationTracking {
        render()
    } onChange: {
        // Fires just before the change; re-render on the next main-actor turn, after it lands.
        Task { @MainActor in renderOnChange(render) }
    }
}
