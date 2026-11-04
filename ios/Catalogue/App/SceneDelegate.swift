import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let container = AppContainer.live(configuration: AppConfiguration.load())
        let coordinator = AppCoordinator(container: container)

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.current.palette.accent
        window.rootViewController = coordinator.navigationController
        window.makeKeyAndVisible()
        coordinator.start()

        self.window = window
        self.coordinator = coordinator
    }
}
