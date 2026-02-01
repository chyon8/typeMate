import Cocoa
import CoreGraphics

/// Manages low-level keyboard event monitoring and text injection.
/// Uses CGEventTap to intercept keystrokes and simulating input.
class InputManager {
    
    // MARK: - Properties
    
    /// Event tap port
    private var eventTap: CFMachPort?
    
    /// Run loop source
    private var runLoopSource: CFRunLoopSource?
    
    /// (Removed duplicate property)
    
    // MARK: - Public Methods
    
    /// Starts monitoring keyboard events
    func startMonitoring() {
        guard eventTap == nil else { 
            print("[InputManager] Already monitoring")
            return 
        }
        
        let eventsOfInterest: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        // Create event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventsOfInterest,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<InputManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[InputManager] Failed to create event tap. Check permissions.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[InputManager] Started monitoring keyboard events")
        }
    }
    
    /// Stops monitoring keyboard events
    func stopMonitoring() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        print("[InputManager] Stopped monitoring")
    }
    
    /// Injects text at the current cursor position
    /// - Parameter text: The text to inject
    func injectText(_ text: String) {
        // 1. Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 2. Simulate Cmd+V
        simulatePasteCommand()
        
        // Note: Restoring previous clipboard content is skipped for simplicity as per requirements
    }
    
    // MARK: - Private Methods
    
    /// Handles incoming events from the tap
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Only interested in keyDown
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        
        // Check for Cmd + Shift + I (KeyCode 34)
        if keyCode == 34 && flags.contains(.maskCommand) && flags.contains(.maskShift) {
            print("[InputManager] Shortcut Cmd+Shift+I detected!")
            
            DispatchQueue.main.async { [weak self] in
                self?.onTriggerShortcut?()
            }
            
            // Swallow the event
            return nil
        }
        
        // Check for Cmd + Shift + C (KeyCode 8)
        if keyCode == 8 && flags.contains(.maskCommand) && flags.contains(.maskShift) {
            print("[InputManager] Shortcut Cmd+Shift+C detected!")
            
            DispatchQueue.main.async { [weak self] in
                self?.onSaveContext?()
            }
            
            // Swallow the event
            return nil
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    /// Callback when the trigger shortcut is pressed (Cmd+Shift+I)
    var onTriggerShortcut: (() -> Void)?
    
    /// Callback when the save context shortcut is pressed (Cmd+Shift+C)
    var onSaveContext: (() -> Void)?
    
    /// Simulates Cmd+V keystroke
    private func simulatePasteCommand() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand
        
        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand
        
        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand
        
        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        // Post events
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
