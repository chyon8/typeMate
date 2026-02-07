import Foundation

/// Anthropic Claude API service implementation
final class ClaudeService: AIServiceProtocol {
    
    let provider: AIProvider = .claude
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model: String
    
    init(model: String = "claude-3-5-sonnet-latest") {
        self.model = model
    }
    
    func generate(
        request: AIGenerationRequest,
        completion: @escaping (Result<AIGenerationResponse, AIError>) -> Void
    ) {
        guard let apiKey = APIKeyManager.shared.getKey(for: .claude) else {
            completion(.failure(.noAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Include instruction for multiple suggestions in user prompt
        let userPromptWithInstruction = """
        \(request.userPrompt)
        
        ---
        
        Please provide 3 different suggestion options, numbered 1, 2, 3. Each should be a complete alternative response.
        """
        
        let body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "system": request.systemPrompt,
            "messages": [
                ["role": "user", "content": userPromptWithInstruction]
            ]
        ]
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.networkError(error)))
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // Check for API errors
                if let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 500
                    if code == 429 {
                        completion(.failure(.rateLimited))
                    } else {
                        completion(.failure(.serverError(code, message)))
                    }
                    return
                }
                
                // Parse content
                guard let content = json["content"] as? [[String: Any]],
                      let first = content.first,
                      let text = first["text"] as? String else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // Parse the numbered suggestions from the response
                let suggestions = self.parseSuggestions(from: text)
                
                // Parse usage
                var usage: AIUsage?
                if let usageData = json["usage"] as? [String: Any] {
                    usage = AIUsage(
                        promptTokens: usageData["input_tokens"] as? Int ?? 0,
                        completionTokens: usageData["output_tokens"] as? Int ?? 0,
                        totalTokens: (usageData["input_tokens"] as? Int ?? 0) + (usageData["output_tokens"] as? Int ?? 0)
                    )
                }
                
                let response = AIGenerationResponse(
                    suggestions: suggestions,
                    rawResponse: text,
                    usage: usage
                )
                
                completion(.success(response))
                
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    /// Parses numbered suggestions from AI response
    private func parseSuggestions(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var suggestions: [String] = []
        var currentSuggestion = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if let match = trimmed.range(of: #"^[1-3][.):]\s*"#, options: .regularExpression) {
                if !currentSuggestion.isEmpty {
                    suggestions.append(currentSuggestion.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentSuggestion = String(trimmed[match.upperBound...])
            } else if !currentSuggestion.isEmpty {
                currentSuggestion += "\n" + trimmed
            }
        }
        
        if !currentSuggestion.isEmpty {
            suggestions.append(currentSuggestion.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        if suggestions.isEmpty {
            suggestions = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return suggestions
    }
}
