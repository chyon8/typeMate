import Cocoa
import ApplicationServices

/// Data structure holding the snapshot of the user's current context
struct CapturedContext {
    let appName: String
    let selectedText: String
    let selectionBounds: CGRect?
}

/// Reads user context by focusing ONLY on the selected text.
final class ContextReader {
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Captures the currently selected text.
    /// - Returns: A `CapturedContext` object containing selected text and bounds.
    func captureContext() -> CapturedContext? {
        guard AccessibilityPermissionManager.shared.isTrusted else {
            print("[ContextReader] Error: Accessibility permission not granted")
            AccessibilityPermissionManager.shared.requestPermission()
            return nil
        }
        
        let systemWide = AXUIElementCreateSystemWide()
        
        // 1. Get System Focused Element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            print("[ContextReader] Failed to get focused element")
            return nil
        }
        
        let axElement = element as! AXUIElement
        
        // 2. Identify App Name
        let appName = getAppName(from: axElement)
        
        // 3. Read Selected Text
        let (selectedText, bounds) = readSelectedText(from: axElement)
        
        // If no text is selected, we might want to return nil or an empty context.
        // For now, let's return it anyway to show "No selection" in debug.
        
        return CapturedContext(
            appName: appName,
            selectedText: selectedText,
            selectionBounds: bounds
        )
    }
    
    // MARK: - Private Methods
    
    private func readSelectedText(from element: AXUIElement) -> (String, CGRect?) {
        // Try Key: kAXSelectedTextAttribute
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        
        guard result == .success, let text = value as? String, !text.isEmpty else {
            return ("", nil)
        }
        
        // Try getting bounds of the selection
        // Method: Use parameterized attribute kAXBoundsForRangeParameterizedAttribute
        // We first need the selected range
        
        var rangeValue: CFTypeRef?
        var rect: CGRect? = nil
        
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success {
            var boundsValue: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue!, &boundsValue) == .success {
                 var r = CGRect.zero
                 if AXValueGetValue(boundsValue as! AXValue, .cgRect, &r) {
                     // Verify rect is valid (sometimes returns 0,0,0,0 or infinite)
                     if r.width > 0 && r.height > 0 {
                         rect = r
                     }
                 }
            }
        }
        
        // Fallback: If we can't get selection bounds, try getting the element's bounds
        if rect == nil {
            rect = getElementFrame(element)
        }
        
        return (text, rect)
    }
    
    private func getElementFrame(_ element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success else {
            return nil
        }
        
        var pos = CGPoint.zero
        var sz = CGSize.zero
        
        guard AXValueGetValue(position as! AXValue, .cgPoint, &pos),
              AXValueGetValue(size as! AXValue, .cgSize, &sz) else {
            return nil
        }
        
        return CGRect(origin: pos, size: sz)
    }
    
    private func getAppName(from element: AXUIElement) -> String {
        var current = element
        while true {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
            
            if let roleStr = role as? String, roleStr == kAXApplicationRole {
                var title: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &title)
                return (title as? String) ?? "Unknown App"
            }
            
            var parent: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
            if result != .success || parent == nil {
                break
            }
            current = parent as! AXUIElement
        }
        return "Unknown App"
    }
}
