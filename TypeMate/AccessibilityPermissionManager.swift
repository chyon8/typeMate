import Cocoa
import ApplicationServices

/// Manages accessibility permission checking and requests for the TypeMate app.
/// This class uses macOS Accessibility APIs to verify if the app is trusted.
final class AccessibilityPermissionManager {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = AccessibilityPermissionManager()
    
    /// Timer for periodic permission checking
    private var permissionCheckTimer: Timer?
    
    /// Callback for permission status changes
    var onPermissionStatusChanged: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Permission Checking
    
    /// Check if the app has accessibility permissions granted.
    /// Uses `AXIsProcessTrusted()` from ApplicationServices framework.
    var isTrusted: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    /// Request accessibility permission with UI prompt.
    /// This will show the system dialog asking user to grant permission.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if trusted {
            print("[AccessibilityPermissionManager] Already trusted.")
        } else {
            print("[AccessibilityPermissionManager] Requesting permission via system prompt...")
        }
    }
    
    // MARK: - System Settings
    
    /// Open the Privacy & Security > Accessibility settings panel in System Settings.
    /// Uses `NSWorkspace` to open the specific settings URL.
    func openAccessibilitySettings() {
        // URL scheme for Privacy & Security > Accessibility panel
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            print("[AccessibilityPermissionManager] Error: Failed to create settings URL")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Permission Monitoring
    
    /// Start monitoring permission status changes.
    /// Checks permission status every 2 seconds and calls the callback on changes.
    func startMonitoring() {
        // Stop any existing timer
        stopMonitoring()
        
        var lastStatus = isTrusted
        
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentStatus = self.isTrusted
            if currentStatus != lastStatus {
                lastStatus = currentStatus
                DispatchQueue.main.async {
                    self.onPermissionStatusChanged?(currentStatus)
                }
            }
        }
    }
    
    /// Stop monitoring permission status changes.
    func stopMonitoring() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    deinit {
        stopMonitoring()
    }
}
