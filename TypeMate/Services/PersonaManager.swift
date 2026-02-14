import Foundation

/// Manages personas for AI style/tone selection.
/// Handles persistence to JSON file in Application Support.
final class PersonaManager {
    
    // MARK: - Singleton
    
    static let shared = PersonaManager()
    
    private init() {
        load()
    }
    
    // MARK: - Properties
    
    private(set) var personas: [Persona] = []
    var selectedPersona: Persona?
    
    private let fileName = "personas.json"
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TypeMate")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent(fileName)
    }
    
    // MARK: - Public Methods
    
    /// Loads personas from disk, or creates defaults if none exist
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            personas = try JSONDecoder().decode([Persona].self, from: data)
            print("[PersonaManager] Loaded \(personas.count) personas")
            
            // Set default selection
            selectedPersona = personas.first(where: { $0.isDefault }) ?? personas.first
        } catch {
            print("[PersonaManager] No existing file, creating defaults")
            personas = Persona.defaults
            selectedPersona = personas.first(where: { $0.isDefault })
            save()
        }
    }
    
    /// Saves current personas to disk
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(personas)
            try data.write(to: fileURL)
            print("[PersonaManager] Saved \(personas.count) personas")
        } catch {
            print("[PersonaManager] Save failed: \(error)")
        }
    }
    
    /// Adds a new persona
    func add(_ persona: Persona) {
        personas.append(persona)
        save()
    }
    
    /// Updates an existing persona
    func update(_ persona: Persona) {
        guard let index = personas.firstIndex(where: { $0.id == persona.id }) else { return }
        personas[index] = persona
        save()
    }
    
    /// Deletes a persona by ID
    func delete(_ id: UUID) {
        personas.removeAll { $0.id == id }
        if selectedPersona?.id == id {
            selectedPersona = personas.first
        }
        save()
    }
    
    /// Selects a persona and updates usage stats. Pass nil to deselect (empty persona).
    func select(_ persona: Persona?) {
        selectedPersona = persona
        
        // Update usage stats
        guard let persona = persona,
              let index = personas.firstIndex(where: { $0.id == persona.id }) else { return }
        personas[index].usageCount += 1
        personas[index].lastUsed = Date()
        save()
    }
    
    /// Sets a persona as the default
    func setDefault(_ id: UUID) {
        for i in personas.indices {
            personas[i].isDefault = (personas[i].id == id)
        }
        save()
    }
}
