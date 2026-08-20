import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 通知をタップしたときに、その通知が指す日のカードを開くために必要。
    // flutter_local_notifications の iOS セットアップ手順（README「iOS setup /
    // General setup」）で必須とされている1行で、これが無いと通知そのものは
    // 届くのにタップだけが機能しない。
    //
    // iOS は通知のタップを UNUserNotificationCenter の delegate へ渡す。
    // delegate を設定しないとタップがプラグインまで届かず、通知が運んでいる
    // payload（開くカードの日付。例 card:2026-08-21）が捨てられる。すると
    // アプリ側は通常の起動と区別が付かず、音声入力画面から始まってしまうため、
    // 「明日の安心カード」ではなく「今日の安心カード」に辿り着く。
    // （お客様ご指摘 2026/08/17）
    //
    // 条件付きキャストは手順どおり。FlutterAppDelegate が
    // UNUserNotificationCenterDelegate に適合している場合にのみ設定される。
    //
    // ■ この行を消さないこと
    // 消しても Dart 側のテストはすべて通る。通知タップの受け渡しは実機でしか
    // 確認できないため、テストでは気づけない。
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
