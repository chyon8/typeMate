import Foundation

/// Represents an AI model provider
enum AIProvider: String, Codable, CaseIterable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case claude = "Claude"
    
    var displayName: String { rawValue }
    
    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o"
        case .gemini: return "gemini-2.0-flash"
        case .claude: return "claude-3-5-sonnet-latest"
        }
    }
}

/// Request structure for AI generation
struct AIGenerationRequest {
    let systemPrompt: String
    let userPrompt: String
    let maxTokens: Int
    
    init(systemPrompt: String, userPrompt: String, maxTokens: Int = 1024) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.maxTokens = maxTokens
    }
}

/// Response from AI generation
struct AIGenerationResponse {
    let suggestions: [String]
    let rawResponse: String
    let usage: AIUsage?
}

struct AIUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// Error types for AI operations
enum AIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case rateLimited
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured"
        case .invalidResponse:
            return "Invalid response from AI"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited, please try again later"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

/// Protocol for AI service implementations
protocol AIServiceProtocol {
    var provider: AIProvider { get }
    
    func generate(
        request: AIGenerationRequest,
        completion: @escaping (Result<AIGenerationResponse, AIError>) -> Void
    )
}
