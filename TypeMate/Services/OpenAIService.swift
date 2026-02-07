import Foundation

/// OpenAI API service implementation
final class OpenAIService: AIServiceProtocol {
    
    let provider: AIProvider = .openai
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model: String
    
    init(model: String = "gpt-4o") {
        self.model = model
    }
    
    func generate(
        request: AIGenerationRequest,
        completion: @escaping (Result<AIGenerationResponse, AIError>) -> Void
    ) {
        guard let apiKey = APIKeyManager.shared.getKey(for: .openai) else {
            completion(.failure(.noAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": request.userPrompt]
            ],
            "max_tokens": request.maxTokens,
            "n": 3  // Generate 3 suggestions
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
                
                // Parse choices
                guard let choices = json["choices"] as? [[String: Any]] else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                let suggestions = choices.compactMap { choice -> String? in
                    guard let message = choice["message"] as? [String: Any],
                          let content = message["content"] as? String else {
                        return nil
                    }
                    return content.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Parse usage
                var usage: AIUsage?
                if let usageData = json["usage"] as? [String: Any] {
                    usage = AIUsage(
                        promptTokens: usageData["prompt_tokens"] as? Int ?? 0,
                        completionTokens: usageData["completion_tokens"] as? Int ?? 0,
                        totalTokens: usageData["total_tokens"] as? Int ?? 0
                    )
                }
                
                let response = AIGenerationResponse(
                    suggestions: suggestions,
                    rawResponse: String(data: data, encoding: .utf8) ?? "",
                    usage: usage
                )
                
                completion(.success(response))
                
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
}
