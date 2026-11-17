import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let chats = ChatListViewController()
        let navigation = UINavigationController(rootViewController: chats)
        navigation.navigationBar.prefersLargeTitles = false
        navigation.navigationBar.tintColor = Palette.accent
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        self.window = window
    }
}
