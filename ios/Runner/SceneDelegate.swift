import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard
      let windowScene = scene as? UIWindowScene,
      let window = windowScene.windows.first,
      let controller = window.rootViewController as? FlutterViewController
    else { return }

    FlutterMethodChannel(
      name: "com.example.tracker/battery",
      binaryMessenger: controller.binaryMessenger
    ).setMethodCallHandler { call, result in
      guard call.method == "getBatteryLevel" else {
        result(FlutterMethodNotImplemented); return
      }
      let device = UIDevice.current
      device.isBatteryMonitoringEnabled = true
      let level = device.batteryLevel
      // batteryLevel is -1 on simulator or when monitoring is unsupported
      result(level < 0 ? -1 : Int(level * 100))
    }
  }
}