import Cocoa
import ApplicationServices

/// Reads user context by tracking cursor position and focused element.
/// Only runs when explicitly requested (Passive Mode).
final class ContextReader {
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Captures the current context immediately.
    /// - Returns: The cursor position in screen coordinates, or nil if failed.
    func captureContext() -> CGPoint? {
        guard AccessibilityPermissionManager.shared.isTrusted else {
            print("[ContextReader] Error: Accessibility permission not granted")
            AccessibilityPermissionManager.shared.requestPermission()
            return nil
        }
        
        return getFocusedTextCursorPosition()
    }
    
    // MARK: - Accessibility API
    
    /// Get the cursor position from the currently focused text field
    private func getFocusedTextCursorPosition() -> CGPoint? {
        // Get system-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            return nil
        }
        
        let axElement = element as! AXUIElement
        
        // Get the selected text range to find cursor position
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        guard rangeResult == .success, let range = selectedRange else {
            // Fallback: use mouse position if text range fails
            return NSEvent.mouseLocation
        }
        
        // Get bounds for the selected text range
        var bounds: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            axElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        )
        
        guard boundsResult == .success, let boundsValue = bounds else {
            return NSEvent.mouseLocation
        }
        
        // Extract CGRect from AXValue
        var rect = CGRect.zero
        if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) {
            // Convert to screen coordinates (bottom-left origin)
            // The rect gives us the cursor position in screen coordinates
            let screenHeight = NSScreen.main?.frame.height ?? 0
            let cursorPoint = CGPoint(
                x: rect.origin.x + rect.width,
                y: screenHeight - rect.origin.y - rect.height
            )
            return cursorPoint
        }
        
        return NSEvent.mouseLocation
    }
}
