import Foundation
import Security

/// Manages API keys for AI providers using Keychain for secure storage.
final class APIKeyManager {
    
    // MARK: - Singleton
    
    static let shared = APIKeyManager()
    
    private init() {}
    
    // MARK: - Private
    
    private let service = "com.typemate.apikeys"
    
    // MARK: - Public Methods
    
    /// Saves an API key for the specified provider
    func saveKey(_ key: String, for provider: AIProvider) throws {
        let account = provider.rawValue
        
        // Delete existing key first
        try? deleteKey(for: provider)
        
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        
        print("[APIKeyManager] Saved key for \(provider.rawValue)")
    }
    
    /// Retrieves the API key for the specified provider
    func getKey(for provider: AIProvider) -> String? {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    /// Deletes the API key for the specified provider
    func deleteKey(for provider: AIProvider) throws {
        let account = provider.rawValue
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Checks if an API key exists for the provider
    func hasKey(for provider: AIProvider) -> Bool {
        return getKey(for: provider) != nil
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode API key"
        case .saveFailed(let status):
            return "Failed to save to Keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain: \(status)"
        }
    }
}
