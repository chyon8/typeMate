import Foundation

/// Google Gemini API service implementation
final class GeminiService: AIServiceProtocol {
    
    let provider: AIProvider = .gemini
    
    private let model: String
    
    init(model: String = "gemini-2.0-flash") {
        self.model = model
    }
    
    private var baseURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
    }
    
    func generate(
        request: AIGenerationRequest,
        completion: @escaping (Result<AIGenerationResponse, AIError>) -> Void
    ) {
        guard let apiKey = APIKeyManager.shared.getKey(for: .gemini) else {
            completion(.failure(.noAPIKey))
            return
        }
        
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gemini uses a different structure - combine system + user into one prompt
        let combinedPrompt = """
        \(request.systemPrompt)
        
        ---
        
        \(request.userPrompt)
        
        ---
        
        Please provide 3 different suggestion options, numbered 1, 2, 3. Each should be a complete alternative response.
        """
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": combinedPrompt]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": request.maxTokens,
                "temperature": 0.8
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
                    completion(.failure(.serverError(code, message)))
                    return
                }
                
                // Parse candidates
                guard let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // Parse the numbered suggestions from the response
                let suggestions = self.parseSuggestions(from: text)
                
                // Parse usage
                var usage: AIUsage?
                if let usageData = json["usageMetadata"] as? [String: Any] {
                    usage = AIUsage(
                        promptTokens: usageData["promptTokenCount"] as? Int ?? 0,
                        completionTokens: usageData["candidatesTokenCount"] as? Int ?? 0,
                        totalTokens: usageData["totalTokenCount"] as? Int ?? 0
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
        // Try to extract numbered items (1. xxx, 2. xxx, 3. xxx)
        let lines = text.components(separatedBy: .newlines)
        var suggestions: [String] = []
        var currentSuggestion = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line starts with a number
            if let match = trimmed.range(of: #"^[1-3][.):]\s*"#, options: .regularExpression) {
                // Save previous suggestion
                if !currentSuggestion.isEmpty {
                    suggestions.append(currentSuggestion.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                // Start new suggestion
                currentSuggestion = String(trimmed[match.upperBound...])
            } else if !currentSuggestion.isEmpty {
                // Continue current suggestion
                currentSuggestion += "\n" + trimmed
            }
        }
        
        // Don't forget the last one
        if !currentSuggestion.isEmpty {
            suggestions.append(currentSuggestion.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // If parsing failed, just return the whole text as one suggestion
        if suggestions.isEmpty {
            suggestions = [text.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        
        return suggestions
    }
}
