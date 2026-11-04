import UIKit

/// WenKey 容器 App 入口。容器 App 本身不输入，只做设置、剪贴板管理与词库管理。
/// P0 的设置页只有启用说明与状态展示；调色 UI 在 P4、剪贴板管理在 P3、词库管理在 P1。
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
