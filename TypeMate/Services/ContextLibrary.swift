import Foundation

/// Manages saved contexts for AI background information.
/// Supports both inline text and external Markdown files.
final class ContextLibrary {
    
    // MARK: - Singleton
    
    static let shared = ContextLibrary()
    
    private init() {
        load()
    }
    
    // MARK: - Properties
    
    private(set) var contexts: [Context] = []
    var selectedContext: Context?
    
    private let fileName = "contexts.json"
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TypeMate")
        
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        return appFolder.appendingPathComponent(fileName)
    }
    
    // MARK: - Public Methods
    
    /// Loads contexts from disk
    func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            contexts = try decoder.decode([Context].self, from: data)
            print("[ContextLibrary] Loaded \(contexts.count) contexts")
        } catch {
            print("[ContextLibrary] No existing file or parse error: \(error)")
            contexts = []
        }
    }
    
    /// Saves current contexts to disk
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(contexts)
            try data.write(to: fileURL)
            print("[ContextLibrary] Saved \(contexts.count) contexts")
        } catch {
            print("[ContextLibrary] Save failed: \(error)")
        }
    }
    
    /// Adds a new inline context
    func addInline(name: String, content: String) {
        let context = Context(
            name: name,
            source: .inline(content)
        )
        contexts.append(context)
        save()
    }
    
    /// Adds a new file-based context
    func addFile(name: String, path: String) {
        let context = Context(
            name: name,
            source: .file(path)
        )
        contexts.append(context)
        save()
    }
    
    /// Updates an existing context
    func update(_ context: Context) {
        guard let index = contexts.firstIndex(where: { $0.id == context.id }) else { return }
        contexts[index] = context
        save()
    }
    
    /// Deletes a context by ID
    func delete(_ id: UUID) {
        contexts.removeAll { $0.id == id }
        if selectedContext?.id == id {
            selectedContext = nil
        }
        save()
    }
    
    /// Selects a context and updates usage stats
    func select(_ context: Context?) {
        selectedContext = context
        
        guard let context = context,
              let index = contexts.firstIndex(where: { $0.id == context.id }) else { return }
        
        contexts[index].usageCount += 1
        contexts[index].lastUsed = Date()
        save()
    }
    
    /// Gets the content of the selected context (if any)
    func getSelectedContent() -> String? {
        return selectedContext?.getContent()
    }
}
