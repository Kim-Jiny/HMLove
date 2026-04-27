import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    // Flutter's scene forwarder doesn't deliver URL events to plugins that
    // only implement UIApplicationDelegate's open-URL hook (home_widget, etc).
    // Mirror the URL into the app delegate so those plugins still see it.
    guard let url = URLContexts.first?.url else { return }
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }
}
