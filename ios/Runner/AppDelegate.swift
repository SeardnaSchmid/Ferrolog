import Flutter
import UIKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, AVAudioPlayerDelegate {
  private var player: AVAudioPlayer?
  private let restIds = ["rest.warning", "rest.end"]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(name: "ferrolog/alert", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "restOver", let args = call.arguments as? [String: Any] else {
          result(FlutterMethodNotImplemented); return
        }
        let beep = args["beep"] as? String ?? "end"
        if args["vibrate"] as? Bool == true {
          UIImpactFeedbackGenerator(style: beep == "end" ? .heavy : .light).impactOccurred()
        }
        if args["sound"] as? Bool == true { self?.play(beep) }
        result(nil)
      }
    FlutterMethodChannel(name: "ferrolog/notify", binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "askPermission":
          UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { allowed, _ in
            DispatchQueue.main.async { result(allowed) }
          }
        case "training":
          if let args = call.arguments as? [String: Any] { self.schedule(args) }
          result(nil)
        case "trainingStop":
          UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: self.restIds)
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// The countdown's beeps: "twice" (rest 30 and 15 s, lead-in 10 s), "last" (3, 2, 1), "end" (0, go).
  private func play(_ beep: String) {
    let file = ["twice": "rest_warning", "last": "rest_last"][beep] ?? "rest_end"
    guard let url = Bundle.main.url(forResource: file, withExtension: "wav") else { return }
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, options: [.duckOthers])
      try session.setActive(true)
      player = try AVAudioPlayer(contentsOf: url)
      player?.delegate = self
      player?.play()
    } catch { try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) }
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    self.player = nil
  }

  private func schedule(_ args: [String: Any]) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: restIds)
    guard let end = args["restEnd"] as? NSNumber else { return }
    let seconds = end.doubleValue / 1000 - Date().timeIntervalSince1970
    let sound = args["sound"] as? Bool ?? true
    if !sound && !(args["vibrate"] as? Bool ?? true) { return }
    // In the background only 30 s before and the end; a notification per second would be too much.
    for (id, delay, file) in [("rest.warning", seconds - 30, "rest_warning.wav"), ("rest.end", seconds, "rest_end.wav")] {
      if delay <= 0 || (id == "rest.warning" && !(args["warning"] as? Bool ?? true)) { continue }
      let content = UNMutableNotificationContent()
      content.title = args[id == "rest.warning" ? "warningTitle" : "alertTitle"] as? String ?? ""
      content.body = args["alertText"] as? String ?? ""
      if sound { content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: file)) }
      center.add(UNNotificationRequest(identifier: id, content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)))
    }
  }
}
