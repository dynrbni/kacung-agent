import Foundation
import AppKit

public final class HotkeyManager {
    public static let shared = HotkeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    public var onHotkeyTriggered: (() -> Void)?

    private var isControlOptionActive = false
    private var lastTriggerTime: TimeInterval = 0

    private init() {}

    /**
     * Registers global and local monitors for Control + Option (⌃⌥).
     * Triggers when user presses Control and Option together, or Control + Option + Space.
     */
    public func registerHotkey() {
        unregisterHotkey()

        // Local monitor (when app has focus)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self = self else { return event }
            if self.processEvent(event: event) {
                return nil // consume event
            }
            return event
        }

        // Global monitor (when any other application is in foreground)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self = self else { return }
            _ = self.processEvent(event: event)
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

    private func processEvent(event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isControl = flags.contains(.control)
        let isOption = flags.contains(.option)
        let hasOtherModifiers = flags.contains(.command) || flags.contains(.shift)

        // Case 1: Modifier keys combination (Control + Option pressed together)
        if event.type == .flagsChanged {
            let active = isControl && isOption && !hasOtherModifiers
            if active {
                if !isControlOptionActive {
                    isControlOptionActive = true
                    triggerDebounced()
                    return true
                }
            } else {
                isControlOptionActive = false
            }
            return false
        }

        // Case 2: Key down with Control + Option (e.g. Space with Control+Option)
        if event.type == .keyDown && isControl && isOption && !hasOtherModifiers {
            if event.keyCode == 49 { // Space
                triggerDebounced()
                return true
            }
        }

        return false
    }

    private func triggerDebounced() {
        let now = Date().timeIntervalSince1970
        guard now - lastTriggerTime > 0.35 else { return }
        lastTriggerTime = now
        DispatchQueue.main.async { [weak self] in
            print("[HotkeyManager] Control + Option triggered!")
            self?.onHotkeyTriggered?()
        }
    }
}
