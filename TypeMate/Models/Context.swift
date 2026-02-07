import Foundation

/// Context type: inline text or external Markdown file
enum ContextSourceType: Codable, Equatable {
    case inline(String)       // Short text stored directly
    case file(String)         // Path to Markdown file
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let value = try container.decode(String.self, forKey: .value)
        
        switch type {
        case "inline":
            self = .inline(value)
        case "file":
            self = .file(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown context type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inline(let text):
            try container.encode("inline", forKey: .type)
            try container.encode(text, forKey: .value)
        case .file(let path):
            try container.encode("file", forKey: .type)
            try container.encode(path, forKey: .value)
        }
    }
}

/// Represents a saved context that provides background information to AI.
struct Context: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var source: ContextSourceType
    var usageCount: Int
    var lastUsed: Date
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        source: ContextSourceType,
        usageCount: Int = 0,
        lastUsed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
    }
    
    /// Returns the actual content of this context
    func getContent() -> String {
        switch source {
        case .inline(let text):
            return text
        case .file(let path):
            let url = URL(fileURLWithPath: path)
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }
    
    /// Short preview of the content for UI display
    var preview: String {
        switch source {
        case .inline(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(50)) + (trimmed.count > 50 ? "..." : "")
        case .file(let path):
            return "📄 " + (path as NSString).lastPathComponent
        }
    }
}
