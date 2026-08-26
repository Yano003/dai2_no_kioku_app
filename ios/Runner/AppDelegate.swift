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

    // 予定データ（sqflite の DB ファイル）を iCloud バックアップの対象から
    // 除外する。プライバシーポリシーの「端末内にのみ保存」という前提を
    // 保つために必要（弁護士レビュー 2026/08/26 対応）。sqflite 自体には
    // この機能が無いため、Dart 側（app_database.dart）から DB ファイルの
    // 絶対パスを渡してもらい、ここでファイル属性を立てる。
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackupExclusionChannel") {
      let channel = FlutterMethodChannel(
        name: "jp.co.hitokoto.kiokuwo/backup_exclusion",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "exclude",
              let args = call.arguments as? [String: Any],
              let path = args["path"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        var url = URL(fileURLWithPath: path)
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
          try url.setResourceValues(resourceValues)
          result(true)
        } catch {
          result(FlutterError(
            code: "EXCLUDE_FROM_BACKUP_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
