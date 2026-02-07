import Cocoa

/// Settings window for managing API keys, personas, and contexts.
class SettingsWindow: NSWindow {
    
    // MARK: - Properties
    
    private var tabView: NSTabView!
    private var apiKeyFields: [AIProvider: NSSecureTextField] = [:]
    private var providerPopup: NSPopUpButton!
    
    // Persona management
    private var personaTableView: NSTableView!
    private var personaNameField: NSTextField!
    private var personaPromptField: NSTextView!
    
    // Context management
    private var contextTableView: NSTableView!
    private var contextNameField: NSTextField!
    private var contextTypePopup: NSPopUpButton!
    private var contextContentField: NSTextView!
    private var contextFileButton: NSButton!
    private var selectedFilePath: String?
    
    // MARK: - Initialization
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "TypeMate Settings"
        self.center()
        self.isReleasedWhenClosed = false
        self.minSize = NSSize(width: 500, height: 400)
        
        setupUI()
        loadSettings()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        tabView = NSTabView(frame: NSRect(x: 20, y: 20, width: 560, height: 460))
        tabView.autoresizingMask = [.width, .height]
        
        // Tab 1: API Keys
        let apiKeysTab = NSTabViewItem(identifier: "apiKeys")
        apiKeysTab.label = "API Keys"
        apiKeysTab.view = createAPIKeysView()
        tabView.addTabViewItem(apiKeysTab)
        
        // Tab 2: Model Settings
        let modelTab = NSTabViewItem(identifier: "model")
        modelTab.label = "Model"
        modelTab.view = createModelView()
        tabView.addTabViewItem(modelTab)
        
        // Tab 3: Personas
        let personaTab = NSTabViewItem(identifier: "personas")
        personaTab.label = "페르소나"
        personaTab.view = createPersonaView()
        tabView.addTabViewItem(personaTab)
        
        // Tab 4: Contexts
        let contextTab = NSTabViewItem(identifier: "contexts")
        contextTab.label = "컨텍스트"
        contextTab.view = createContextView()
        tabView.addTabViewItem(contextTab)
        
        contentView?.addSubview(tabView)
    }
    
    // MARK: - API Keys Tab
    
    private func createAPIKeysView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
        
        var yOffset: CGFloat = 360
        
        for provider in AIProvider.allCases {
            let label = NSTextField(labelWithString: "\(provider.displayName) API Key:")
            label.frame = NSRect(x: 20, y: yOffset, width: 150, height: 20)
            view.addSubview(label)
            
            let field = NSSecureTextField(frame: NSRect(x: 180, y: yOffset, width: 300, height: 24))
            field.placeholderString = "sk-... or AIza..."
            apiKeyFields[provider] = field
            view.addSubview(field)
            
            let statusLabel = NSTextField(labelWithString: "")
            statusLabel.frame = NSRect(x: 490, y: yOffset, width: 30, height: 20)
            statusLabel.alignment = .center
            if APIKeyManager.shared.hasKey(for: provider) {
                statusLabel.stringValue = "✓"
                statusLabel.textColor = .systemGreen
            }
            view.addSubview(statusLabel)
            
            yOffset -= 50
        }
        
        let saveButton = NSButton(title: "Save API Keys", target: self, action: #selector(saveAPIKeys))
        saveButton.frame = NSRect(x: 220, y: 20, width: 120, height: 32)
        saveButton.bezelStyle = .rounded
        view.addSubview(saveButton)
        
        let infoText = NSTextField(wrappingLabelWithString: "API keys are stored securely in your macOS Keychain.")
        infoText.frame = NSRect(x: 20, y: 60, width: 500, height: 40)
        infoText.textColor = .secondaryLabelColor
        infoText.font = .systemFont(ofSize: 11)
        view.addSubview(infoText)
        
        return view
    }
    
    // MARK: - Model Tab
    
    private func createModelView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
        
        let providerLabel = NSTextField(labelWithString: "Default AI Provider:")
        providerLabel.frame = NSRect(x: 20, y: 360, width: 150, height: 20)
        view.addSubview(providerLabel)
        
        providerPopup = NSPopUpButton(frame: NSRect(x: 180, y: 356, width: 200, height: 28))
        for provider in AIProvider.allCases {
            providerPopup.addItem(withTitle: provider.displayName)
        }
        if let index = AIProvider.allCases.firstIndex(of: AIManager.shared.selectedProvider) {
            providerPopup.selectItem(at: index)
        }
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged)
        view.addSubview(providerPopup)
        
        let statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: 20, y: 300, width: 500, height: 40)
        updateProviderStatus(statusLabel)
        statusLabel.tag = 100
        view.addSubview(statusLabel)
        
        return view
    }
    
    // MARK: - Persona Tab
    
    private func createPersonaView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
        
        // Left: Table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 200, height: 320))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        personaTableView = NSTableView()
        personaTableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 180
        personaTableView.addTableColumn(column)
        personaTableView.delegate = self
        personaTableView.dataSource = self
        personaTableView.target = self
        personaTableView.action = #selector(personaTableClicked)
        scrollView.documentView = personaTableView
        view.addSubview(scrollView)
        
        // Add/Remove buttons
        let addButton = NSButton(title: "+", target: self, action: #selector(addPersona))
        addButton.frame = NSRect(x: 20, y: 50, width: 30, height: 24)
        addButton.bezelStyle = .rounded
        view.addSubview(addButton)
        
        let removeButton = NSButton(title: "−", target: self, action: #selector(removePersona))
        removeButton.frame = NSRect(x: 55, y: 50, width: 30, height: 24)
        removeButton.bezelStyle = .rounded
        view.addSubview(removeButton)
        
        // Right: Editor
        let nameLabel = NSTextField(labelWithString: "이름:")
        nameLabel.frame = NSRect(x: 240, y: 370, width: 50, height: 20)
        view.addSubview(nameLabel)
        
        personaNameField = NSTextField(frame: NSRect(x: 300, y: 368, width: 220, height: 24))
        personaNameField.placeholderString = "페르소나 이름"
        view.addSubview(personaNameField)
        
        let promptLabel = NSTextField(labelWithString: "프롬프트:")
        promptLabel.frame = NSRect(x: 240, y: 340, width: 80, height: 20)
        view.addSubview(promptLabel)
        
        let promptScrollView = NSScrollView(frame: NSRect(x: 240, y: 120, width: 280, height: 210))
        promptScrollView.hasVerticalScroller = true
        promptScrollView.borderType = .bezelBorder
        
        personaPromptField = NSTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 200))
        personaPromptField.isEditable = true
        personaPromptField.font = .systemFont(ofSize: 12)
        personaPromptField.textContainerInset = NSSize(width: 5, height: 5)
        promptScrollView.documentView = personaPromptField
        view.addSubview(promptScrollView)
        
        let savePersonaButton = NSButton(title: "저장", target: self, action: #selector(savePersonaEdit))
        savePersonaButton.frame = NSRect(x: 440, y: 80, width: 80, height: 28)
        savePersonaButton.bezelStyle = .rounded
        view.addSubview(savePersonaButton)
        
        return view
    }
    
    // MARK: - Context Tab
    
    private func createContextView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: 420))
        
        // Left: Table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: 200, height: 320))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        
        contextTableView = NSTableView()
        contextTableView.headerView = nil
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.width = 180
        contextTableView.addTableColumn(column)
        contextTableView.delegate = self
        contextTableView.dataSource = self
        contextTableView.target = self
        contextTableView.action = #selector(contextTableClicked)
        scrollView.documentView = contextTableView
        view.addSubview(scrollView)
        
        // Add/Remove buttons
        let addButton = NSButton(title: "+", target: self, action: #selector(addContext))
        addButton.frame = NSRect(x: 20, y: 50, width: 30, height: 24)
        addButton.bezelStyle = .rounded
        view.addSubview(addButton)
        
        let removeButton = NSButton(title: "−", target: self, action: #selector(removeContext))
        removeButton.frame = NSRect(x: 55, y: 50, width: 30, height: 24)
        removeButton.bezelStyle = .rounded
        view.addSubview(removeButton)
        
        // Right: Editor
        let nameLabel = NSTextField(labelWithString: "이름:")
        nameLabel.frame = NSRect(x: 240, y: 370, width: 50, height: 20)
        view.addSubview(nameLabel)
        
        contextNameField = NSTextField(frame: NSRect(x: 300, y: 368, width: 220, height: 24))
        contextNameField.placeholderString = "컨텍스트 이름"
        view.addSubview(contextNameField)
        
        let typeLabel = NSTextField(labelWithString: "타입:")
        typeLabel.frame = NSRect(x: 240, y: 340, width: 50, height: 20)
        view.addSubview(typeLabel)
        
        contextTypePopup = NSPopUpButton(frame: NSRect(x: 300, y: 336, width: 120, height: 28))
        contextTypePopup.addItem(withTitle: "텍스트")
        contextTypePopup.addItem(withTitle: "파일")
        contextTypePopup.target = self
        contextTypePopup.action = #selector(contextTypeChanged)
        view.addSubview(contextTypePopup)
        
        contextFileButton = NSButton(title: "파일 선택...", target: self, action: #selector(selectContextFile))
        contextFileButton.frame = NSRect(x: 430, y: 336, width: 90, height: 28)
        contextFileButton.bezelStyle = .rounded
        contextFileButton.isHidden = true
        view.addSubview(contextFileButton)
        
        let contentLabel = NSTextField(labelWithString: "내용:")
        contentLabel.frame = NSRect(x: 240, y: 305, width: 80, height: 20)
        view.addSubview(contentLabel)
        
        let contentScrollView = NSScrollView(frame: NSRect(x: 240, y: 120, width: 280, height: 175))
        contentScrollView.hasVerticalScroller = true
        contentScrollView.borderType = .bezelBorder
        
        contextContentField = NSTextView(frame: NSRect(x: 0, y: 0, width: 260, height: 165))
        contextContentField.isEditable = true
        contextContentField.font = .systemFont(ofSize: 12)
        contextContentField.textContainerInset = NSSize(width: 5, height: 5)
        contentScrollView.documentView = contextContentField
        view.addSubview(contentScrollView)
        
        let saveContextButton = NSButton(title: "저장", target: self, action: #selector(saveContextEdit))
        saveContextButton.frame = NSRect(x: 440, y: 80, width: 80, height: 28)
        saveContextButton.bezelStyle = .rounded
        view.addSubview(saveContextButton)
        
        return view
    }
    
    private func updateProviderStatus(_ label: NSTextField) {
        let configured = AIManager.shared.configuredProviders
        if configured.isEmpty {
            label.stringValue = "⚠️ No API keys configured. Add keys in the API Keys tab."
            label.textColor = .systemOrange
        } else {
            let names = configured.map { $0.displayName }.joined(separator: ", ")
            label.stringValue = "✓ Configured: \(names)"
            label.textColor = .systemGreen
        }
    }
    
    // MARK: - Actions
    
    @objc private func saveAPIKeys() {
        for (provider, field) in apiKeyFields {
            let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                do {
                    try APIKeyManager.shared.saveKey(key, for: provider)
                    print("[Settings] Saved key for \(provider.displayName)")
                } catch {
                    print("[Settings] Failed to save key for \(provider.displayName): \(error)")
                }
            }
        }
        
        let alert = NSAlert()
        alert.messageText = "API Keys Saved"
        alert.informativeText = "Your API keys have been saved to the Keychain."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        if let modelView = tabView.tabViewItem(at: 1).view,
           let statusLabel = modelView.viewWithTag(100) as? NSTextField {
            updateProviderStatus(statusLabel)
        }
    }
    
    @objc private func providerChanged() {
        let index = providerPopup.indexOfSelectedItem
        guard index >= 0 && index < AIProvider.allCases.count else { return }
        AIManager.shared.selectedProvider = AIProvider.allCases[index]
        print("[Settings] Selected provider: \(AIManager.shared.selectedProvider.displayName)")
    }
    
    // MARK: - Persona Actions
    
    @objc private func personaTableClicked() {
        let row = personaTableView.selectedRow
        guard row >= 0 && row < PersonaManager.shared.personas.count else { return }
        let persona = PersonaManager.shared.personas[row]
        personaNameField.stringValue = persona.name
        personaPromptField.string = persona.prompt
    }
    
    @objc private func addPersona() {
        let newPersona = Persona(
            id: UUID(),
            name: "새 페르소나",
            prompt: "You are a helpful assistant.",
            isDefault: false,
            usageCount: 0,
            lastUsed: Date(),
            createdAt: Date()
        )
        PersonaManager.shared.add(newPersona)
        personaTableView.reloadData()
        
        // Select the new item
        let newRow = PersonaManager.shared.personas.count - 1
        personaTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        personaTableClicked()
    }
    
    @objc private func removePersona() {
        let row = personaTableView.selectedRow
        guard row >= 0 && row < PersonaManager.shared.personas.count else { return }
        let persona = PersonaManager.shared.personas[row]
        PersonaManager.shared.delete(persona.id)
        personaTableView.reloadData()
        personaNameField.stringValue = ""
        personaPromptField.string = ""
    }
    
    @objc private func savePersonaEdit() {
        let row = personaTableView.selectedRow
        guard row >= 0 && row < PersonaManager.shared.personas.count else { return }
        
        var persona = PersonaManager.shared.personas[row]
        persona.name = personaNameField.stringValue
        persona.prompt = personaPromptField.string
        PersonaManager.shared.update(persona)
        personaTableView.reloadData()
        
        ToastWindow.show("페르소나 저장됨")
    }
    
    // MARK: - Context Actions
    
    @objc private func contextTableClicked() {
        let row = contextTableView.selectedRow
        guard row >= 0 && row < ContextLibrary.shared.contexts.count else { return }
        let context = ContextLibrary.shared.contexts[row]
        contextNameField.stringValue = context.name
        
        switch context.source {
        case .inline(let text):
            contextTypePopup.selectItem(at: 0)
            contextContentField.string = text
            contextContentField.isEditable = true
            contextFileButton.isHidden = true
            selectedFilePath = nil
        case .file(let path):
            contextTypePopup.selectItem(at: 1)
            contextContentField.string = path
            contextContentField.isEditable = false
            contextFileButton.isHidden = false
            selectedFilePath = path
        }
    }
    
    @objc private func contextTypeChanged() {
        let isFile = contextTypePopup.indexOfSelectedItem == 1
        contextFileButton.isHidden = !isFile
        contextContentField.isEditable = !isFile
        if isFile {
            contextContentField.string = selectedFilePath ?? "파일을 선택하세요"
        } else {
            contextContentField.string = ""
        }
    }
    
    @objc private func selectContextFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFilePath = url.path
            contextContentField.string = url.path
        }
    }
    
    @objc private func addContext() {
        ContextLibrary.shared.addInline(name: "새 컨텍스트", content: "")
        contextTableView.reloadData()
        
        let newRow = ContextLibrary.shared.contexts.count - 1
        contextTableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        contextTableClicked()
    }
    
    @objc private func removeContext() {
        let row = contextTableView.selectedRow
        guard row >= 0 && row < ContextLibrary.shared.contexts.count else { return }
        let context = ContextLibrary.shared.contexts[row]
        ContextLibrary.shared.delete(context.id)
        contextTableView.reloadData()
        contextNameField.stringValue = ""
        contextContentField.string = ""
    }
    
    @objc private func saveContextEdit() {
        let row = contextTableView.selectedRow
        guard row >= 0 && row < ContextLibrary.shared.contexts.count else { return }
        
        var context = ContextLibrary.shared.contexts[row]
        context.name = contextNameField.stringValue
        
        if contextTypePopup.indexOfSelectedItem == 0 {
            // Inline text
            context.source = .inline(contextContentField.string)
        } else {
            // File
            if let path = selectedFilePath {
                context.source = .file(path)
            }
        }
        
        ContextLibrary.shared.update(context)
        contextTableView.reloadData()
        
        ToastWindow.show("컨텍스트 저장됨")
    }
    
    // MARK: - Load Settings
    
    private func loadSettings() {
        // Tables will load from managers automatically via dataSource
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension SettingsWindow: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == personaTableView {
            return PersonaManager.shared.personas.count
        } else if tableView == contextTableView {
            return ContextLibrary.shared.contexts.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellId = NSUserInterfaceItemIdentifier("cell")
        
        var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = cellId
        }
        
        if tableView == personaTableView && row < PersonaManager.shared.personas.count {
            cell?.stringValue = PersonaManager.shared.personas[row].name
        } else if tableView == contextTableView && row < ContextLibrary.shared.contexts.count {
            cell?.stringValue = ContextLibrary.shared.contexts[row].name
        }
        
        return cell
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var settingsWindow: SettingsWindow?
    
    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

