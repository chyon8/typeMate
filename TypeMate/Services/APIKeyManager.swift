import Foundation

/// Manages API keys for AI providers using UserDefaults.
final class APIKeyManager {
    
    // MARK: - Singleton
    
    static let shared = APIKeyManager()
    
    private init() {}
    
    // MARK: - Private
    
    private let prefix = "com.typemate.apikey."
    
    // MARK: - Public Methods
    
    /// Saves an API key for the specified provider
    func saveKey(_ key: String, for provider: AIProvider) throws {
        UserDefaults.standard.set(key, forKey: prefix + provider.rawValue)
        print("[APIKeyManager] Saved key for \(provider.rawValue)")
    }
    
    /// Retrieves the API key for the specified provider
    func getKey(for provider: AIProvider) -> String? {
        let key = UserDefaults.standard.string(forKey: prefix + provider.rawValue)
        return (key?.isEmpty == false) ? key : nil
    }
    
    /// Deletes the API key for the specified provider
    func deleteKey(for provider: AIProvider) throws {
        UserDefaults.standard.removeObject(forKey: prefix + provider.rawValue)
    }
    
    /// Checks if an API key exists for the provider
    func hasKey(for provider: AIProvider) -> Bool {
        return getKey(for: provider) != nil
    }
}

// MARK: - Errors (kept for API compatibility)

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode API key"
        case .saveFailed(let status):
            return "Failed to save key: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete key: \(status)"
        }
    }
}
