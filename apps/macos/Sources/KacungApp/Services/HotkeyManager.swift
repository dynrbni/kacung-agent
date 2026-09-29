import Foundation
import AppKit

public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    public var onHotkeyTriggered: (() -> Void)?

    private init() {}

    /**
     * Registers global hotkey for Option + Space.
     * Clearly marked as a development fallback feature until local on-device wake-word model is attached.
     */
    public func registerHotkey() {
        unregisterHotkey()

        // Local monitor (when app has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isOptionSpace(event: event) == true {
                self?.onHotkeyTriggered?()
                return nil // consume event
            }
            return event
        }

        // Global monitor (when any other application is in foreground)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.isOptionSpace(event: event) == true {
                DispatchQueue.main.async {
                    self?.onHotkeyTriggered?()
                }
            }
        }
    }

    public func unregisterHotkey() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func isOptionSpace(event: NSEvent) -> Bool {
        // Space keyCode is 49
        let isSpace = event.keyCode == 49
        let hasOption = event.modifierFlags.contains(.option)
        let hasCommand = event.modifierFlags.contains(.command)
        let hasControl = event.modifierFlags.contains(.control)

        // Matches Option + Space (without Command or Control to avoid collision with Spotlight / Raycast)
        return isSpace && hasOption && !hasCommand && !hasControl
    }
}
