import Foundation

/// Central manager for AI operations.
/// Handles provider selection and request routing.
final class AIManager {
    
    // MARK: - Singleton
    
    static let shared = AIManager()
    
    private init() {
        // Load saved provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedAIProvider"),
           let provider = AIProvider(rawValue: savedProvider) {
            self.selectedProvider = provider
        }
    }
    
    // MARK: - Properties
    
    /// Currently selected AI provider
    var selectedProvider: AIProvider = .openai {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedAIProvider")
        }
    }
    
    /// Get the appropriate service for the selected provider
    private var currentService: AIServiceProtocol {
        switch selectedProvider {
        case .openai:
            return OpenAIService()
        case .gemini:
            return GeminiService()
        case .claude:
            return ClaudeService()
        }
    }
    
    // MARK: - Public Methods
    
    /// Generates AI suggestions based on current context
    func generateSuggestions(
        persona: Persona?,
        projectContext: String?,
        screenContext: String?,
        selection: String?,
        userInstruction: String?,
        completion: @escaping (Result<[String], AIError>) -> Void
    ) {
        // Build system prompt (empty if no persona selected)
        var systemPrompt = persona?.prompt ?? ""
        
        if let projectContext = projectContext, !projectContext.isEmpty {
            systemPrompt += "\n\n### 프로젝트 배경 정보:\n\(projectContext)"
        }
        
        // Build user prompt
        var userPrompt = ""
        
        if let screenContext = screenContext, !screenContext.isEmpty {
            userPrompt += "### 현재 화면 컨텍스트:\n\(screenContext)\n\n"
        }
        
        if let selection = selection, !selection.isEmpty {
            userPrompt += "### 선택된 텍스트 (응답 또는 변환 대상):\n\(selection)\n\n"
        }
        
        if let instruction = userInstruction, !instruction.isEmpty {
            userPrompt += "### 사용자 지시:\n\(instruction)\n\n"
        }
        
        // Default instruction if none provided
        if userPrompt.isEmpty {
            userPrompt = "위 맥락을 바탕으로 3가지 다른 버전의 답변을 1, 2, 3 번호를 붙여서 제시하세요. 각각은 완전한 독립 답변이어야 합니다."
        } else {
            userPrompt += "위 맥락을 바탕으로 3가지 다른 버전의 답변을 1, 2, 3 번호를 붙여서 제시하세요. 각각은 완전한 독립 답변이어야 합니다. 번호와 답변 내용만 출력하세요."
        }
        
        let request = AIGenerationRequest(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
        
        print("[AIManager] Generating with \(selectedProvider.displayName)")
        print("[AIManager] System: \(systemPrompt.prefix(100))...")
        print("[AIManager] User: \(userPrompt.prefix(100))...")
        
        currentService.generate(request: request) { result in
            switch result {
            case .success(let response):
                print("[AIManager] Got \(response.suggestions.count) suggestions")
                if let usage = response.usage {
                    print("[AIManager] Tokens: \(usage.totalTokens)")
                }
                completion(.success(response.suggestions))
                
            case .failure(let error):
                print("[AIManager] Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Checks if the current provider has an API key configured
    var hasAPIKey: Bool {
        APIKeyManager.shared.hasKey(for: selectedProvider)
    }
    
    /// Returns providers that have API keys configured
    var configuredProviders: [AIProvider] {
        AIProvider.allCases.filter { APIKeyManager.shared.hasKey(for: $0) }
    }
}
