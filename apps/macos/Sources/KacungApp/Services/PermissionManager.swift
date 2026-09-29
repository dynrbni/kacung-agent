import Foundation
import AVFoundation
import AppKit

public final class PermissionManager {
    public static let shared = PermissionManager()

    private init() {}

    public var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }

    public var isMicrophoneGranted: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    public func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openSystemSettings(for type: String) {
        var urlString = "x-apple.systempreferences:com.apple.preference.security"
        if type == "accessibility" {
            urlString += "?Privacy_Accessibility"
        } else if type == "microphone" {
            urlString += "?Privacy_Microphone"
        }
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
