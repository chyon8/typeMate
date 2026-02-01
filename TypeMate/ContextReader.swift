import Cocoa
import ApplicationServices

/// Data structure holding the snapshot of the user's current context
struct CapturedContext {
    let appName: String
    let selectedText: String // Captured Background Context (from Window scan)
    let valueText: String    // Input (Full Content of Field)
    let selectionBounds: CGRect?
}

/// Reads user context by scanning the active window's UI hierarchy.
final class ContextReader {
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Captures the currently selected text and the surrounding window context.
    /// - Returns: A `CapturedContext` object containing input text and background context.
    func captureContext() -> CapturedContext? {
        guard AccessibilityPermissionManager.shared.isTrusted else {
            print("[ContextReader] Error: Accessibility permission not granted")
            AccessibilityPermissionManager.shared.requestPermission()
            return nil
        }
        
        guard let axElement = getFocusedElement() else {
            print("[ContextReader] Failed to get focused element")
            return nil
        }
        
        return captureContext(from: axElement)
    }
    
    /// Gets the currently focused UI element. Call this on main thread BEFORE showing any windows.
    func getFocusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            return nil
        }
        return (element as! AXUIElement)
    }
    
    /// Captures context from a pre-captured element. Safe to call from background thread.
    func captureContext(from axElement: AXUIElement) -> CapturedContext? {
        // 1. Identify App Name
        let appName = getAppName(from: axElement)
        
        // 2. Read Input Text (What user is typing)
        let valueText = readValueText(from: axElement)
        let bounds = getElementFrame(axElement)
        
        // 3. Scan Background Context (What user is looking at)
        // If the user hasn't manually selected text, we scan the window.
        // If they HAVE selected text, we prioritize that.
        let (manualSelection, _) = readSelectedText(from: axElement)
        var contextText = manualSelection
        
        if contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // No manual selection -> Scan the window!
            contextText = scanWindowContext(from: axElement)
        }
        
        return CapturedContext(
            appName: appName,
            selectedText: contextText,
            valueText: valueText,
            selectionBounds: bounds
        )
    }
    
    // MARK: - Private Methods
    
    /// Scans the entire window containing the focused element to find specific text.
    /// BRUTE FORCE: Checks every possible text attribute on every element.
    private func scanWindowContext(from focusedElement: AXUIElement) -> String {
        // 1. Find the Window
        guard let window = getWindow(from: focusedElement) else { return "" }
        
        // 2. Try to find a Content Container to narrow down search
        var targetRoot = window
        if let webArea = findContentContainer(in: window) {
            targetRoot = webArea
        }
        
        // 3. AGGRESSIVE DFS - Collect ALL text from children
        var collectedTexts: [String] = []
        var stack: [AXUIElement] = [targetRoot]
        var visitedCount = 0
        var collectedLength = 0
        let maxVisits = 3000 // Deep scan restored
        let maxTextLength = 5000 // Allow more text before early exit
        
        while !stack.isEmpty && visitedCount < maxVisits && collectedLength < maxTextLength {
            let current = stack.removeLast()
            visitedCount += 1
            
            // Skip the focused element itself (we already have it as Input)
            if CFEqual(current, focusedElement) { continue }
            
            // NO GEOMETRY FILTER - Removed sidebar check to get everything
            
            // BRUTE FORCE TEXT EXTRACTION: Try ALL possible text attributes
            let allTexts = getAllTextFromElement(current)
            for text in allTexts {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                // Keep texts longer than 2 characters
                if trimmed.count > 2 {
                    collectedTexts.append(trimmed)
                    collectedLength += trimmed.count
                }
            }
            
            // Add ALL Children to Stack
            if let children = getChildren(from: current) {
                stack.append(contentsOf: children.reversed())
            }
        }
        
        // Deduplicate consecutive identical texts (common in Slack UI)
        var deduped: [String] = []
        for text in collectedTexts {
            if deduped.last != text {
                deduped.append(text)
            }
        }
        
        // Join with newlines
        let fullContext = deduped.joined(separator: "\n")
        
        // Limit context size
        return String(fullContext.prefix(5000))
    }
    
    /// Extracts ALL possible text strings from an element using every known attribute
    private func getAllTextFromElement(_ element: AXUIElement) -> [String] {
        var results: [String] = []
        
        // List of all attributes that might contain text
        let textAttributes: [String] = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXHelpAttribute as String,
            kAXRoleDescriptionAttribute as String
        ]
        
        for attr in textAttributes {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success {
                if let str = value as? String, !str.isEmpty {
                    results.append(str)
                }
            }
        }
        
        return results
    }
    
    /// Heuristic Search: Looks for a major content container (WebArea, TextArea, Group)
    private func findContentContainer(in root: AXUIElement) -> AXUIElement? {
        var queue: [AXUIElement] = [root]
        var visits = 0
        
        while !queue.isEmpty && visits < 200 { // Increased search depth
            let current = queue.removeFirst()
            visits += 1
            
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
            
            if let roleStr = role as? String {
                // Priority 1: Web Area (Chrome, Safari, Slack, Electron)
                if roleStr == "AXWebArea" { return current }
                // Priority 2: Text Area (Editors)
                if roleStr == kAXTextAreaRole { return current }
                // Priority 3: Scroll Area (often contains content lists)
                if roleStr == kAXScrollAreaRole { return current }
            }
            
            if let children = getChildren(from: current) {
                queue.append(contentsOf: children)
            }
        }
        return nil
    }
    
    private func getTextContent(from element: AXUIElement) -> String? {
        // Try Value first
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
           let str = value as? String {
            return str
        }
        
        // Try Title/Description
        var title: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title) == .success,
           let str = title as? String {
            return str
        }
        
        // Accessibility Label/Description
        var desc: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc) == .success,
            let str = desc as? String {
            return str
        }
        
        return nil
    }
    
    private func getChildren(from element: AXUIElement) -> [AXUIElement]? {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        if result == .success, let array = children as? [AXUIElement] {
            return array
        }
        return nil
    }
    
    private func getWindow(from element: AXUIElement) -> AXUIElement? {
        var current = element
        while true {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
            
            if let roleStr = role as? String, roleStr == kAXWindowAttribute {
                return current
            }
            
            var parent: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent)
            if result != .success || parent == nil {
                break
            }
            current = parent as! AXUIElement
        }
        return nil
    }
    
    private func readSelectedText(from element: AXUIElement) -> (String, CGRect?) {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        
        guard result == .success, let text = value as? String, !text.isEmpty else {
            return ("", nil)
        }
        return (text, nil)
    }
    
    private func readValueText(from element: AXUIElement) -> String {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success, let text = value as? String else {
            return ""
        }
        return text
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
