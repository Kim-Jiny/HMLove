import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else {
      super.scene(scene, openURLContexts: URLContexts)
      return
    }

    // 앱 자체 스킴(hmlove://) 만 Flutter 라우팅으로 deep link 전달.
    // 카카오 등 소셜 OAuth 콜백(kakao{key}://oauth) 은 native 플러그인만 처리해야지
    // Flutter 라우팅까지 흘러가면 GoRouter 가 매칭 실패 → 현재 화면이 강제 교체된다.
    if url.scheme == "hmlove" {
      super.scene(scene, openURLContexts: URLContexts)
    }

    // Flutter's scene forwarder doesn't deliver URL events to plugins that
    // only implement UIApplicationDelegate's open-URL hook (home_widget,
    // kakao_flutter_sdk 등). Mirror the URL into the app delegate so those
    // plugins still see it.
    _ = UIApplication.shared.delegate?.application?(
      UIApplication.shared,
      open: url,
      options: [:]
    )
  }
}
