import Foundation

/// Singleton manager for storing and retrieving saved context.
/// Handles the priority logic between manual selection and auto-captured context.
final class ContextManager {
    
    // MARK: - Singleton
    
    static let shared = ContextManager()
    
    private init() {}
    
    // MARK: - Properties
    
    /// Manually saved context (via Cmd+Shift+C)
    private(set) var savedContext: String?
    
    /// Whether to use context at all (checkbox state)
    var useContext: Bool = true
    
    // MARK: - Public Methods
    
    /// Saves context from user selection
    /// - Parameter text: The selected text to save as context
    func saveContext(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        savedContext = trimmed
        print("[ContextManager] Context saved: \(trimmed.prefix(50))...")
    }
    
    /// Clears the saved context
    func clearContext() {
        savedContext = nil
        print("[ContextManager] Context cleared")
    }
    
    /// Checks if there is a saved context available
    func hasSavedContext() -> Bool {
        guard let context = savedContext else { return false }
        return !context.isEmpty
    }
    
    /// Gets the effective context based on priority and settings
    /// - Parameter autoContext: The auto-captured context as fallback
    /// - Returns: The context to use, or empty string if disabled
    func getEffectiveContext(autoContext: String) -> String {
        guard useContext else {
            return ""
        }
        
        if hasSavedContext() {
            return savedContext!
        }
        
        return autoContext
    }
}
