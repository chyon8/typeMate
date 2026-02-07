import Foundation

/// Represents an AI persona that defines the style and tone of generated responses.
struct Persona: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String          // Display name with emoji, e.g. "💼 Business"
    var prompt: String        // System prompt for AI
    var isDefault: Bool       // Whether this is the default persona
    var usageCount: Int
    var lastUsed: Date
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        isDefault: Bool = false,
        usageCount: Int = 0,
        lastUsed: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.isDefault = isDefault
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.createdAt = createdAt
    }
}

// MARK: - Default Personas

extension Persona {
    static let defaults: [Persona] = [
        Persona(
            name: "💼 Business Professional",
            prompt: "You are a professional business assistant. Write clear, concise, and polite messages. Avoid jargon unless necessary. Start with the main point. Use bullet points for readability. Tone: Professional but approachable.",
            isDefault: true
        ),
        Persona(
            name: "💬 Friendly Chat",
            prompt: "You are a close friend. Use casual Korean (반말) and internet slang appropriately. Use emojis to express emotion. Keep sentences short but expressive.",
            isDefault: false
        ),
        Persona(
            name: "🍎 iOS Developer",
            prompt: "You are an expert iOS/macOS engineer. Write clean, idiomatic Swift 6 code. Prefer value types, protocol-oriented programming, and modern concurrency. Use guard for early exits. Be concise and focus on the 'why'.",
            isDefault: false
        ),
        Persona(
            name: "🇺🇸 English Mode",
            prompt: "Translate or refine the text into natural, native-sounding English. Choose words that fit the context (formal for business, casual for chat). Correct grammar and awkward phrasing.",
            isDefault: false
        ),
        Persona(
            name: "✍️ Creative Writer",
            prompt: "You are a creative writer. Use evocative language, sensory details, and strong verbs. Avoid clichés. Show, don't just tell.",
            isDefault: false
        )
    ]
}
